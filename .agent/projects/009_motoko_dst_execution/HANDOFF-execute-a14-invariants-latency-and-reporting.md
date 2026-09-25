# Handoff: execute WI-A14 — the D7 invariant set, D4's latency pair, D11 run reporting

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**Cluster 8. WI-A13 completed on 2026-08-03** across six stages (`9c4d724` … `e01a978`); `make dst`
is exit 0 at **466 checks**. Every dependency of this item is landed. **A15 depends on this item and
nothing else does**, so A14 and A15 are sequential, not one cluster.

**Read first:** `NOTE-cluster-12-execution-report-and-plan-corrections.md` — its closing *"Five
things A14 should carry"* is addressed to you and is the densest input you have — then the plan's
`## Standing rules`. **S7 and S8 both bite, and S8's complement was written with this item's latency
pair named as having the same exposure.**

## Mission, in three pieces

Take them as **three commits**, and **partial completion at a piece boundary is a legitimate stop** —
that pattern held for A12's six effect classes and A13's six stages, and cluster 12's retrospective
faulted stage 6 for being *sized as one stage when it was two independent pieces*. These three are
largely independent; say so in your report if that turns out false.

1. **The D7 invariant set** — twelve families over the returned outcome and complete trace.
2. **D4's latency pair** — two replayable programs differing only in generated latency.
3. **D11 run reporting** — the counters, the run report, and D8's CI replay affordance.

Suggested order: invariants, then reporting, then the latency pair last, because the pair needs a
world-input widening the other two do not (below) and is the piece most likely to overrun.

## The rule each piece will break by accident

### Piece 1 — the parity invariant fails today for fifteen variants, and the wrong fix is one field away

`make event_vocabulary` reports it in as many words: **`15 logical variant(s) do NOT reach the
returned trace today — D6.4's gap, for WI-A14`.** D6.4 requires every logical `LedgerEvent` to reach
the returned trace. Twenty-eight of thirty-four are classified `Logical`; only thirteen reach it.

**So a parity invariant written today goes red, and there is a one-line way to make it green that
destroys the point:** reclassify the fifteen as `DisplayOnly`. That type-checks, the artifact still
validates, every count balances, and **D6.4's obligation becomes vacuous — blessing the exact gap it
exists to close.** WI-A8 refused this deliberately and left the evidence in the artifact: the survey
fact lives in a **separate** field, `reaches_trace_today`, precisely so a classification can never be
confused with a measurement. **The fifteen are the work, not the answer.**

**`DoneEvent` is the one that is genuinely undecided, and it is your call.** A8 classified it
`Logical` and recorded why it could not resolve it: D6.3 requires the returned outcome, the
`DoneEvent` and the `RunSummary` to **agree** — an invariant over content, which `DisplayOnly`
denies — while D6.1 requires the `RunSummary` to be the **final** record, and the driver projects the
`DoneEvent` *after* `c2_finalize` has appended the summary. Both cannot hold by appending it where it
is emitted. The resolution is available — append the `DoneEvent` before finalizing — but it changes a
terminal path, which is why A8 handed it here. Decide it; do not inherit it silently.

### Piece 2 — the latency pair is literally an "X influences Y" assertion, so S8 applies in both directions

D4: *"hold the request and underlying completion result constant while changing only latency/clock
advancement, and demonstrate the expected different observed completion-versus-timeout behaviour.
Both programs must replay deterministically."*

That is S8's exact shape, and S8 was written from a defect of precisely this kind — a generator that
reached its output through a **decorative** path (the seed printed into prose) and passed a
sensitivity axis while every trajectory was identical. **Check that latency cannot reach the observed
outcome except through the deadline comparison.** If the two programs differ anywhere else — a
timestamp in a payload, a duration in a message — the pair proves the encoding carries the number,
not that time matters.

**And S8's complement, which is the cheaper failure:** if neither program's trajectory ever *enters*
the timeout branch, the pair certifies nothing and reads identically to a pair that does. Choose
latencies that bind — one under the deadline and one over it, verified by the branch actually being
taken, not by the outcome differing.

**This piece needs a world-input widening the others do not, and it is one field.** The provider
class has **no latency channel**: `ScriptedTool` carries `duration_ms` and `world_tool` advances the
clock from it, while `ScriptedStep` has `prose, tool_calls, input_tokens, output_tokens,
finish_reason, chunks` and no counterpart. Cluster 10 measured this deliberately — its first draft
*did* have the generator choose a provider `advance_ms` and it was silently discarded, because
`recording_model_step` hard-codes `advance_ms: 0`. **The dead field was removed rather than left in**,
and adding it properly is this item's. Restore it on replay from `TimedOutcome.advance_ms` exactly as
the tool duration already is — no codec change. Roughly thirty literal sites across the smoke scripts.

**Check whether that widening is port-shaped before assuming it is free** (cluster 12's item 4):
stages 3–6 all paid nothing for A5's anchors by writing below them and running `sed -n '161p'`, but
cluster 10 and stage 2 both paid a `driver_only` re-issue because **a new `StepProvider` variant
forces a match arm that cannot sit below the sites it precedes.** A `ScriptedStep` *field* is not a
variant — confirm that before you start, and if it is free, say so, because that is the fourth data
point on a decision A14/A15 owns.

### Piece 3 — three unreached fault classes, three different reasons, three counters

Cluster 12 is emphatic and it is the easiest thing here to get wrong by tidying:

| Class | Why unreached | Counter must say |
|---|---|---|
| `approval_deadline_exceeded` | **structurally** — D2 gives `ExpectApproval` a deadline and the driver's approval channel carries none; `DenyAfterTimeout` is a decision, not a duration | unreachable, a declared gap |
| the provider fault class | **one field away** — piece 2's widening; A13's generator cannot produce it | reachable once piece 2 lands |
| `ToolCorrelationMismatch`, `ToolDeadlineExceeded` | **codec-covered, scenario-unreached** — they travel the same codec as `ToolFailed` and are pinned by round-trip rows | covered but not exercised |

Merging them into one "unreached" number reports three different facts as one, and a waiver is not
one of the three. D3 requires a waived class to be **named with its waiving condition**; none of
these is waived.

**And D8's clause the reporting piece must not violate:** *"a digest without retained bytes is not
sufficient for replay."* The encoding enforces it. **A report that names only a hash would
reintroduce at the reporting layer exactly what the artifact refuses to represent.** `artifact_path`
gives the reference and `load_program` the command's other half; `persist_message` already prints
both.

## Inputs, verified at HEAD

**Run `git diff --stat 506a677..HEAD -- src packages scripts Makefile` first; if non-empty,
re-verify.**

| Input | Where |
|---|---|
| The event vocabulary, `reaches_trace_today`, `logical_variants_not_in_trace()`, `classification_findings()` | `dst_event_vocabulary.ail:59, 117` |
| `ScriptedStep` (6 fields, **no latency**) and `ScriptedTool` (`duration_ms`, the precedent) | `ports.ail` |
| A9's result types — `SystemRun`, `HarnessFailure`, `DstResult`, `ReplayMetadata` | `dst_result.ail` |
| A7's catalogue — `required_class_ids()`, `conditional_class_ids`, `waiving_condition` | `dst_fault_catalogue.ail:165, 500, 511` |
| A13's replay — `strict_replay_findings`, `regression_replay_findings`, `regression_report`, `world_state_of` | `dst_replay.ail` |
| A13's generator, bounds, canary | `dst_generator.ail` |
| A13's persistence — `persist_program`, `load_program`, `artifact_path`, `artifact_identity`, `program_digest` | `dst_persistence.ail` |
| A10's profile and manifest — `driver_only()` v3, `validate_driver_only`, `driver_only_manifest`, `replay_metadata_of` | `dst_driver_only.ail`, `dst_profile.ail` |
| D7's twelve invariant families | ADR `### D7` |

## Definition of done

**Every D7 family has a runnable invariant**, evaluated over the whole execution — outcome plus
complete trace — not per step. The parity family is decided rather than made vacuous, per piece 1.

**The latency pair demonstrates the differing deadline outcome, both programs replay
deterministically**, and the branch is shown to be taken rather than inferred from the outcome.

**The run report carries D11's full field list**: generator id/version, attempted seeds, completed
`SystemRun` count, harness/generator failures, fault classes reached, **named recovery branches
reached**, waived classes with conditions, terminal reasons reached, elapsed budget. Class-reached
and branch-reached stay **separate counters read from A7's artifact** — reaching a class is not
evidence its production branch executed, and only the second is the coverage the acceptance test
asks for.

**The env class's completeness evidence is reported as a different kind** (cluster 7/8): six classes
have an independent runtime witness, environment reads have none and rest on a **source-derived** key
set asserting **multiplicity, not presence** — the driver reads `MOTOKO_TOOL_TIMEOUT_MS` once per
native tool dispatch, so a recorder logging the first read of each key looks complete.

**Per S7, asserted executably:** any surviving fixture carries every shape the specification protects
with **no two of its quantities equal**. Per cluster 12's limit, **sweep-and-filter selects among
things that exist and cannot cover a space the producer does not reach** — where the generator cannot
reach a shape, construct against a derived requirement instead of selecting against a derived filter.

**Every structural guard mutation-tested** (C5), each row asserting **its own rule** rather than a
non-empty finding list — cluster 12 showed that is what stops a guard passing on the wrong evidence.
Any new grep-based Makefile guard **anchored to a syntactic form**.

## Out of scope

- **A15's two corpora and their CI jobs** — the next cluster. Select them by the sweep-and-filter
  technique with cluster 12's limit applied, and key on `artifact_identity`, not on
  `(id, version, seed)`, which is provably not unique (site 22, plus the manifest argument).
- **`routing_violation_at`'s call site** — WI-C5's, on structural grounds.
- **Fixing `seed_state`** — deferred with a named owner; A15 holds the residue.
- **Shrinking** — deferred past the first name-adoption gate, recorded.
- **Anything in Milestone B or C.** The upstream recorded-stream API has still not shipped in a
  released AILANG, so the repin and the name gate remain externally blocked.

## Decisions this item owns

Two, both handed here by name, neither of which should be resolved silently:

1. **`DoneEvent`'s classification and the terminal-path change it implies** — piece 1.
2. **Whether to build a coordinate-independent anchor for A5's table before the name gate.** Cluster
   8 paid a five-artifact cascade; cluster 9 avoided one by care and weakened the case; cluster 10
   showed **half is not avoidable by care** and restored it; stages 3–6 then paid nothing. The
   evidence is now four stages deep and it is your call. A symbol name plus a content digest of the
   enclosing function is the candidate.

And one to resolve rather than carry: **`max_resource_size` is bound to the synthetic environment's
entry count and measures nothing in a real run.** It is now encoded and round-tripped, so **deleting
it is a schema change** — which is the point of having a schema version. Give it a resource that can
grow, or delete it.

## Traps

**Run `make dst` and read `$?`.** Fifth consecutive item where this mattered. **Do not run other
`make` targets concurrently with it.** The single `✗` in a green log is the `✗ Failed: 0` summary
label of a passing `ailang test` run — check it rather than assuming either way.

**A5 anchors: `stub_step.ail:161`, `session.ail`'s 948/1053/2290/2400; `driver_only` is v3.**

**Two AILANG defects will bite this item's shape**, both filed and both with one-line workarounds:
a call in the field-value position of a record update is not registered as a dependency, giving a
bogus `undefined variable` that reordering does not reliably fix — `let`-bind the call
(`fb_e44ba922db1c42be`); and an out-of-scope constructor name in a pattern binds as a fresh variable,
making the arm irrefutable and later arms dead with `ailang check` clean (`fb_b39697480a4e8bbc`).
Both are written up in `.agent/issues/`.

Clear `.ailang/cache` before believing a contradicting type error. Rebuild the parallel `ailang check`
closure tool. Never probe from `/tmp`. Pin is v0.26.0.

## Report back

Thirteenth calibration run.

- **The git wall-clock window** — handoff commit to last `feat` commit — **not a felt ratio.**
  Cluster 12 measured both for all six A13 stages and they disagree by two to three times; stage 2's
  contemporaneous "~3×" is **1.26×** on the clock. A felt ratio may sit beside the window, labelled.
- **Recorded bindings, split decided versus discovered, and per piece.** S6 now carries both
  refinements, and cluster 12 found the **discovered** count predicts better than the total.
- **Judgement ratio, split** machinery versus content, per piece.
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** Twenty-four across twelve clusters; **determinism has caught none.** Cluster 12's
  first item is the sharpest statement of why: every silent defect in six stages was found by
  mutating the implementation and reading *why* a row went red — never by running the gate.
- Anything the plan or ADR got wrong.
