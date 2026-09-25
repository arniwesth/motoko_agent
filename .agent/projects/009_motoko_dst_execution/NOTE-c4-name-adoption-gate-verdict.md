# WI-C4 — the name-adoption gate, run row by row. **VERDICT: NO.**

Twenty-fourth calibration run. Written against HEAD `0dfb67a`, branch
`arniwesth/mot-63-execute-wi-c4`.

## Window

**~40 minutes** wall-clock: `2026-08-05T12:46Z` → `2026-08-05T13:26Z`. Grounding was clean: `git
status` clean at `0dfb67a`, which is the fourth handoff in a row to get commit state right — though
the handoff's own header says branch `mot-62`, and the branch is `mot-63`. Harmless, noted once.

**This item built no evidence and wrote no production code.** It ran gates, read their output, and
repaired one gate that was lying. That repair is described below and is the item's second finding.

## THE VERDICT

**NO. `driver_only` does not adopt the "DST" or "simulation" name.** Seven of eleven rows hold; four
do not. **Seven consecutive items have now declined the name, and this is the first one to have
actually run the table.**

Two of the seven passes are **vacuous in named clauses** and are marked as such below. Per D10 a
vacuous pass does not transfer to another profile — a second profile earns those rows again from
scratch, and for the boundary row it earns them non-vacuously or not at all.

## The eleven answers

| # | Row | Verdict | Produced by |
|---|---|---|---|
| 1 | Does one seed generate an execution rather than only values? | **PASS** | `discovery` · `seeded_generator` · `execution_program` |
| 2 | Is there a modeled logical environment? | **PASS** (qualified — see row 10) | `world_state` · A12 |
| 3 | Is the tested boundary honest? | **PASS — VACUOUS** in every installed-extension clause | `driver_only` v7 · `profile_coverage` · `profile_definition` · `hook_guard` |
| 4 | Do injected faults reach production recovery code? | **RED** | `corpus_pr` · `corpus_rotating` · D11 counters |
| 5 | Does virtual time matter? | **PASS** — real, with a transferability caveat | `driver_only.routed_set_claim` · `world_state` Clock pair · `latency_pair` |
| 6 | Is production logic under test? | **PASS** | `smoke_driver` · `terminal_trace` · `world_state` |
| 7 | Is the oracle complete? | **RED** | `invariants` · `d64_gap_register` |
| 8 | Are harness failures separate? | **PASS** | `strict_replay` · `world_state` poison pairs |
| 9 | Are discovery and replay stable? | **PASS** | `discovery` · `strict_replay` |
| 10 | Is hermeticity enforced? | **RED** on the host-env clause | `world_state` |
| 11 | Is there actual search? | **RED** | `corpus_pr` · `corpus_rotating` |

Row-by-row evidence follows. Every number below is from the `make dst` run recorded in this item,
not transcribed from a prior report.

### 1 — one seed generates an execution. PASS

`discovery_dst PASS`, `strict_replay_dst PASS`, `compaction_seeded_dst PASS families=1
base_seed=1 seeds=5`, `phase_c_seeded_dst PASS families=4`. Zero unexpected harness failures. The
census lines record the resolved interaction sequence per scenario and the sequences differ by
scenario — `approve` at `expect_provider=4 expect_tool=3 expect_approval=3 advance_clock=6` against
`deny` at `expect_provider=4 expect_tool=0 expect_approval=3 advance_clock=3`. The corpus bank is
the stronger evidence: twelve swept seeds produce twelve different interaction counts (n=9 … n=50)
and different reached fault classes, so the seed selects an execution rather than a value.

### 2 — a modeled logical environment. PASS, qualified

Provider, typed tool execution, approval, clock and logical resource state thread through one
state-threaded world with checked transitions; `world_state` asserts advancement and
trace-completeness, and the A12 probe's seven assertions go red under the carry-forward mutation.
Runtime randomness is not used (`runtime_random_draw=0` on every census, honestly reported rather
than absent).

**The qualification is the env class and it is booked against row 10, not here**, because the defect
is hermeticity rather than modelling: the world does supply an environment and the driver does act on
it (`environment_read [source-derived-key-set] witnessed=9 logged=9`, asserting multiplicity rather
than presence). What it does not do is *exclude* the ambient one. Stated once, in row 10.

### 3 — the tested boundary is honest. **PASS, AND IT IS VACUOUS. Decided explicitly.**

This is the row the handoff asked to be decided rather than inherited, so here is the decision and
its reasoning.

**Every clause of this row that quantifies over installed extensions is vacuously true, because
`driver_only` installs nothing.** "Every installed extension covers at least one hook", "no installed
extension has an unconditionally-dispatched hook excluded", "no installed extension calls a
classifier-2 `ExtPorts` field while registering an un-excluded hook" — all range over the empty set.
The gate says so itself rather than leaving it to a reader: `✓ an empty install list cannot violate:
vacuous for driver_only, binding from C5`, and `✓ the runtime exclusion check is VACUOUS for
driver_only: nothing installed, nothing excluded, no dispatch can violate`.

**The row still passes, and the reason is the clause the handoff identified.** The row's final clause
— *"the result reports per-extension covered/excluded hook **ids**, so a profile covering only
ABI-pure no-op slots is visible as such"* — asks that a weak profile be VISIBLE, not that it be
strong. `driver_only` names its omission (`compaction_ai`) and states in one recorded paragraph
exactly which four slots are coverable under neither D5 criterion and why. A reader of the result
cannot mistake this profile for a covering one. That is the property the row is written to test, and
it holds.

**What is not vacuous here:** the manifest and profile are named and validate against the definition
they realize (`driver_only/7` under `event-vocabulary/1`, classifier-2 set derived at 2 fields,
unrouted fields derived at 0); the excluded hooks and adapter/parser boundaries are listed; and the
coverage floor binds unconditionally as a rule even where it has nothing to bind over.

**The one clause satisfied only by a synthetic fixture:** "dispatch to an exclusion fails closed."
`make hook_guard` is 4 rows, 0 failed, and it asserts the excluded hook's *body did not run* rather
than merely that the right error came back. But no profile in this tree can reach it — the fixture is
synthetic and the script prints that on every invocation. **The mechanism is demonstrated; it is not
exercised.**

### 4 — injected faults reach production recovery code. **RED**

Measured this run:

```
✓ the corpus validates against 5 expected class(es):
    provider_empty_terminal_response, ToolFailed, ToolCorrelationMismatch,
    ToolDeadlineExceeded, approval_denied
✓ the four unreachable classes are registered with reasons, not waived
✓ expected + unreachable == every required non-waived class (9)
```

**Five of nine required non-waived fault classes are reached. Four are not**, and the corpus module
is explicit that they are gaps rather than permissions — *"a class nobody waived that nobody reached
is a coverage gap, not a permission."* The row requires the corpus to reach **every** required class
the profile does not waive. It reaches five of nine, so the row fails on its own text.

The four, with the reasons already recorded:

| Class | Status | Blocking change |
|---|---|---|
| `provider_error_retryable` | unreachable-until-change | `ScriptedStep` has no error channel |
| `provider_error_non_retryable` | unreachable-until-change | the same missing error case |
| `provider_partial_stream_then_error` | unreachable-structurally | the same field — C3 removed the parity obstacle, the partial-stream half remains |
| `provider_protocol_inconsistent_result` | covered-not-exercised | the generator's `tool_args` are always well-formed JSON. Measured: 0 of 260 |

**Both waived classes are named with their waiving condition, as the row requires** — and one waiver
is vacuous: `extension_effect_fault` is waived because *"driver_only installs none, so it waives this
class by construction."* **That is a waiver purchased by the empty install list**, and per D10 it does
not transfer.

**Note the gate is GREEN over this red row, and that is not a defect in the gate.** `corpus_pr` holds
the bank to `expected_bank_coverage()` = required-non-waived minus the registered-unreachable set,
and reports the register separately. The narrowing is recorded in both directions
(`✓ expected + unreachable == every required non-waived class (9)`) rather than hidden. **The gate
passes its own contract; the ADR row is stricter than the gate.** Anyone reading `make corpus_pr` as
the answer to this row would read a green.

### 5 — virtual time matters. **PASS**, with a caveat about transfer, not about validity

The routed-set claim is **computed, not recorded**: `reachable core sites: 7 / routed: 6 / declared
unrouted: 1`. The one unrouted site is `src/core/test/stub_step.ail:202` — the live adapter, ambient
by design — and its containment is **evidenced rather than asserted**: `make world_state`'s Clock
poison pair shows the deterministic entry point completes with `Clock` withheld (so it does not reach
that site) and the live world dies with `Clock` withheld (so the capability is load-bearing and the
first half is not vacuous). That is a real two-sided probe, and it is why this row passes with a
residual unrouted read on the books.

The latency pair holds: `✓ wire witness: 4 of 9 native_tool_results carry ToolDeadlineExceeded (the
slow halves, and only those)` — with the gate refusing both the zero case and the all-faulted case,
so neither a silent recorder nor a world that faults everything can satisfy it. No OS timeout is
invoked.

**The caveat, and it is about a different profile rather than this one:** `motoko-ext-compose`'s eight
clock reads are unrouted, and they are outside `driver_only`'s reachable set **only because
`driver_only` installs nothing**. This row's pass is real for this profile and buys nothing at all for
the next one.

### 6 — production logic is under test. PASS

The runner calls the real traced session driver with threaded world state; no test transition loop
computes state-machine decisions or history. `smoke_driver` 8 scripts + 6 unit tests, 0 failed;
`terminal_trace_dst PASS` with `✓ all terminal returns route through c2_finalize`. The A12 carry-
forward mutation reddens seven assertions in the probe, which is what makes "the driver actually ran"
falsifiable rather than assumed.

### 7 — the oracle is complete. **RED. This is the item's central finding.**

The row has three conjuncts. Two hold:

- **Exactly one final `RunSummary` per terminal path** — `terminal-summary` family, with
  `✓ mutant: a RunSummary on a harness failure → summary-on-harness-failure` proving it discriminates.
- **All D7 invariants pass** — `✓ the fixture satisfies all twelve families`, `✓ all 12 families
  reached`, `invariants_dst PASS`, 12 families and all 37 `Violation` constructors sampled by name.

**The third does not.** *"All logical ledger emissions appear in the returned trace"* is false for
**thirteen** Logical variants, printed by the gate on every run:

```
i D6.4's remaining gap, 13 variant(s), each with a reason:
   ScratchpadResult, NativeToolDenied, ToolPending, ExtToolHandled,
   DelegatedToolDeferred, V2ToolDispatchStart, V2ToolDispatchComplete,
   Dp7VerifierRejected, CostExhausted, ThinkingStreamEnd,
   NativeToolCalls, NativeToolResults, SessionSuspend
```

**Eleven of the thirteen are reachable under `driver_only`** — the tool-dispatch fold, the
`CostExhausted` and `Dp7VerifierRejected` paths, and `ThinkingStreamEnd`. Only `ScratchpadResult` and
`ExtToolHandled` need an installed extension, and `SessionSuspend` needs a suspend trigger no profile
has. **So the row fails under every reading of "profile-reachable", and that matters**: it means the
tempting narrowing described below cannot even rescue it, which removes the temptation rather than
merely forbidding it.

**C3 discharged D6.4's named stream exception and said in as many words that the general obligation
was not discharged.** This row is that obligation. `make stream_parity` is green on both halves
(`wire_deltas=14 trace_deltas=14`, order and content equal, and the wire gate is out of process) —
that is the *exception*, complete and correct, and it is not the row.

### 8 — harness failures are separate. PASS

`✓ rich: a mismatch returns a typed HarnessFailure with position and projection` and the same for
`maxsteps`; `✓ dispatch reaching an EXCLUDED hook returns a typed HarnessFailure (routing_violation)`;
`✓ mutant: a RunSummary on a harness failure → summary-on-harness-failure` proves no synthetic
production summary is fabricated. The raw capability-bypass poison probes fail the run non-zero and
are kept distinct from the typed class, which is D6.6 in force.

### 9 — discovery and replay are stable. PASS

`discovery_dst PASS`, `strict_replay_dst PASS`. The `rich` scenario's discovery and replay censuses
are identical member for member (`expect_provider=11 expect_tool=3 expect_approval=10
environment_read=8 advance_clock=6` on both sides), replay runs under the recorded manifest without
invoking the generator, and the wire witness is compared out of process so the recorder does not grade
itself.

### 10 — hermeticity is enforced. **RED on the host-env clause**

Three of the four classes the row names are enforced by two-sided poison pairs:

```
✓ deterministic world completes with AI withheld    ✓ live world dies with AI withheld
✓ deterministic world completes with Clock withheld ✓ live world dies with Clock withheld
✓ (typed tool contract, Process withheld — same pair)
```

RNG is honestly reported as unused rather than claimed. **The host-env class has no poison pair:**

```
-- env class --
i Env-withheld pair DEFERRED, not skipped
i the env class's evidence is the provenance assertion in world_state_probe
```

The provenance assertion is real — the world seeds `MOTOKO_HEADLESS`, the driver acts on the world's
value, a control run proves the branches differ, and CI's process environment does not set the
variable, so the world cannot pass by agreeing with it. **But provenance is not hermeticity.** The
reason there is no pair is recorded in the Makefile and is structural: `context_usage.resolve_context_limit`
reads `MOTOKO_MODELS_FILE` / `MOTOKO_REPO` / `MOTOKO_PROFILE_DIR` / `MOTOKO_CONFIG` ambiently at six
driver call sites, and withholding `Env` therefore kills a deterministic run. Those reads are not
routable on their own — every one computes a file path the same function then reads, so threading the
env half alone would hand back a world-supplied path to an ambient file, which is a green check
implying absent coverage.

**So a host-env bypass today neither fails nor is detected, and the row says it must do one or the
other.** RED, on evidence the tree already carried and no gate was asserting.

### 11 — there is actual search. **RED**

The corpora meet their declared minimums, and the minimums are operator-accepted from measured cost:
`✓ dst-pr-corpus: minimum 12 seed(s), budget 5000 ms (17 affordable at 292 ms/seed)`, `✓ the bank's
SEED count meets the declared minimum (12 ≥ 12)`; rotating declares its window size as its minimum so
the job cannot declare a number the rotation does not produce, and both below-minimum and truncated
windows are proven to be rejected. Class- and branch-reached counters are reported and kept separate.
Counterexamples are retained with their manifests — 13 artifact identities and 13 trajectory keys, all
pairwise distinct, with the promoted regression carrying its failure.

**The row fails on one clause: "the fixed bank reaches every required non-waived fault class."** It
reaches five of nine. Same four classes as row 4, same evidence, one underlying cause for three of
them.

## The second finding: a sixth instrument that certified nothing, and this one was a wiring defect

The handoff pointed at `dst_event_vocabulary.ail:808` — *"the register carries the remaining
**fourteen**"* — as stale prose, S15's class, and said **"the assertion beside it is correct and
derives the list; only the prose is stale."**

**That is wrong, and finding out why is worth more than the fix.** The assertion beside it read:

```ailang
List.length(logical_variants_not_in_trace(event_vocabulary())) == 14
  && contains_str(logical_variants_not_in_trace(event_vocabulary()), "StreamDelta")
```

WI-C3 flipped `StreamDelta.reaches_trace_today` to `true`. The gap became 13 and StreamDelta left it.
**`test_logical_gap_is_recorded` has therefore been RED since WI-C3** — through two items whose
reports state that every `make dst` target but two passed.

**It was invisible because of how the Makefile ran it:**

```make
ailang test src/core/dst_event_vocabulary.ail > /dev/null && echo "  ✓ ..."; \
```

Under `set -e`, a failure on the left of `&&` **does not exit** — that is exactly what `&&` is for —
and the following `;` discards the status. The target printed no tick for that file and **exited 0**.
The same form in *terminal* position is safe, because the recipe's status is the last command's. That
is why it survived: **eleven of seventeen sites were fine and the pattern read as uniform.**

**Measured, not assumed:** six sites were in non-terminal position; I ran all six directly, and
**exactly one was masking a real failure**. The other five (`dst_discovery`, `ports`,
`dst_persistence`, `dst_result`, `phase_vocab`) pass on their own.

**Repaired, and the repair is verified falsifiable.** All six now run as checked commands, the stale
literal is 13 with StreamDelta asserted in the negative direction like `DoneEvent`, and the two
further stale counts in `dst_invariants.ail` (`:600` "carries FOURTEEN", `:628` "the remaining
fourteen") are corrected. **Mutation: restoring `== 14` now takes `make event_vocabulary` to exit 2;
before the repair the same mutant exited 0.**

**Three stale instances, not the one the handoff named — S15's exact class, and the third item in
three to carry it.**

## Two rows that disagreed, checked rather than picked

The handoff asked for disagreements to be reported rather than resolved toward the greener. One
surfaced and it resolved benignly; recording it because a naive read of the log gets it wrong.

`run_report_dst` prints **two** windows. The first shows `fault classes reached: 9 of 11` with
`provider_partial_stream_then_error: reached ×1`. The second shows `5 of 11` with the same class
`unreachable-structurally`. The first is the renderer's **complete-window fixture**; the second is
labelled in the output itself — *"TODAY's DOCUMENTED coverage register — declared, not measured."*
**Not two instruments disagreeing; one script demonstrating its renderer and then reporting reality.**
The measured answer is the second, and it agrees with `corpus_pr` exactly.

Also worth keeping straight, because it looks like a contradiction and is not: the register reports
`fault classes reached: 5 of 11` beside `recovery branches reached: 9 of 11`. Branches are reached by
constructed scenarios; classes are reached by search. **D11 keeps these separate precisely so that a
branch reached by a hand-written scenario cannot be read as a class reached by a seed**, and here the
separation is doing visible work.

## The rule I did not break, said plainly

**There are exactly two one-line edits that turn the oracle row green and I made neither.**

1. **Reclassifying the thirteen as DisplayOnly.** `display_only_baseline()` pins the six by name and
   `parity_register_findings` asserts the register equals the vocabulary's gap in both directions, so
   this is red in two places — but the reason not to do it is not that it is guarded. It would make
   D6.4's obligation vacuous for exactly the variants D6.4 exists to cover.
2. **Narrowing what `driver_only` claims to reach.** As noted in row 7, eleven of the thirteen are
   reachable under the profile as it stands, so this would require claiming the profile does not reach
   its own tool-dispatch fold. That is a profile version bump and a conformance decision, and it is
   the same move as reclassification one level up.

**And the third: answering a row by building something.** The only code this item wrote is the repair
to an instrument that was reporting a false green — it produces no evidence for any row, and row 7 is
red with it in place exactly as it was without it.

## The work list behind the NO — every failing row with a named producer

**Row 7 (oracle), the largest.** Close `d64_gap_register`. It splits into four pieces of very
different size and only the first is small:

| Piece | Variants | Note |
|---|---|---|
| Terminal paths | `CostExhausted`, `Dp7VerifierRejected` | Unblocked. The same one-line append `DoneEvent` took. One terminal path at a time |
| The tool-dispatch fold | `NativeToolDenied`, `ToolPending`, `DelegatedToolDeferred`, `V2ToolDispatchStart`, `V2ToolDispatchComplete`, `NativeToolCalls`, `NativeToolResults` | Where the bulk lives. A per-tool-call append inside the fold, with its own red surface |
| The stream bracket | `ThinkingStreamEnd` | `ThinkingStreamStart` reaches the trace and this does not — the same code path appends one bracket and projects the other |
| Gated elsewhere | `ScratchpadResult`, `ExtToolHandled`, `SessionSuspend` | The first two need an installable extension (the `on_budget_plan` ABI change); the third needs a profile with a suspend trigger |

**Rows 4 and 11 (faults and search).** Two named producers close all four classes:

- **An error case on `ScriptedStep`** closes `provider_error_retryable`,
  `provider_error_non_retryable` and `provider_partial_stream_then_error`. One field, three classes,
  **not externally blocked** — the corpus register says so in its own text.
- **A generator that can emit malformed `tool_args`** closes `provider_protocol_inconsistent_result`.

**Row 10 (hermeticity).** A **filesystem class in the world**, so `resolve_context_limit`'s `Env` and
`FS` halves can be routed together. Routing the env half alone is refused on record and correctly so.

## Planning defects found at the gate, named and left

Per the handoff's rule: a row whose evidence no item was scheduled to produce is a plan defect, not an
experiment to run here.

1. **The oracle row has no scheduled producer.** The plan's WI-C4 text asserts *"every row's evidence
   is produced earlier"* and enumerates producers — A14, A15, A4/A5, A12, A9, C3. **No item in the
   plan was ever scheduled to close D6.4's general obligation.** C3 discharged the named stream
   exception only, and said so. This is why the project spent from B4 to C5 tracking the install as
   the blocker: the row that actually blocks the name had no owner, so nothing reported on it.
2. **The hermeticity row's host-env clause has no scheduled producer either.** A12 was to produce the
   hermeticity probes, and A12's specified order contains no filesystem class — so the env pair was
   deferrable at A12 with no later item picking it up. The Makefile already records this as *"reported
   as a plan finding rather than worked around"*; the finding was never lifted into the plan.
3. **The plan's WI-C4 text should say the gate can fail.** It describes running the table and adopting
   the name; it does not say what to do with a NO, which is why "expect NO" had to arrive by handoff
   rather than by plan.

## Recorded bindings: decided versus discovered

**Discovered — a tool or a measurement forced it:**

1. **`test_logical_gap_is_recorded` has been red since WI-C3, and `make event_vocabulary` exited 0
   over it.** Found by noticing the target printed no tick for a file it names. The item's sharpest
   finding and the one that generalises.
2. **The `&& echo` swallow is in six non-terminal sites and was masking exactly one real failure.**
   Measured by running all six directly rather than inferring from the pattern.
3. **The handoff's claim that the assertion beside the stale prose was correct is false.** The
   assertion was the stale thing; the prose merely agreed with it.
4. **Three stale count instances, not one** — `dst_event_vocabulary:808`, `dst_invariants:600`,
   `dst_invariants:628`.
5. **Eleven of the thirteen register entries are `driver_only`-reachable**, which is what makes the
   narrowing escape unavailable rather than merely forbidden. Read off `parity_gap_reasons()`, not
   assumed.
6. **`run_report` prints a fixture window and a measured window that disagree**, and both are
   labelled. Checked before reporting a disagreement that was not one.
7. **The corpus gate is green while row 4 is red**, because it holds the bank to
   `required_non_waived` minus the registered-unreachable set. Recorded in both directions by the
   gate, so this is a stricter-ADR finding rather than a gate defect.

**Decided — a human chose:**

1. **Row 3 passes, on the visibility reading, and is marked VACUOUS in every installed-extension
   clause.** The row anticipates a weak profile and asks that it be visible as one.
2. **Row 5 passes with a residual unrouted site**, because the site is declared, is the live adapter,
   and its unreachability is evidenced by a two-sided poison pair rather than claimed.
3. **The env defect is booked against row 10, not row 2.** One defect, one row, named where it bites.
4. **The gate repair was made rather than only reported.** An instrument reporting a false green is
   not evidence for any row, and leaving it would have made this verdict rest on a target I knew was
   lying. It produces no evidence and changes no row's answer.
5. **All six swallowing sites were fixed, not just the one that was failing.** The other five are one
   edit away from the same silence.
6. **The register was NOT closed and the four fault classes were NOT made reachable.** Both are the
   work list; doing either here would be the gate supplying its own evidence.
7. **The counter is reported as 51 with attribution rather than held at 50.** See below.

## Sites where two answers type-checked and one was silently wrong

**This item wrote no production code and authored none.** It **found one**, pre-existing:

**The stale literal `== 14`.** Both `13` and `14` type-check, both run, and the wrong one is red in a
place nothing reported. It was authored by WI-C3 and invisible until now. **The counter is 51**, from
C5's 50, attributed to C3's edit and recorded at C4 because that is when it became visible — prior
items counted a site at the run that found it, and holding the number at 50 would mean the project's
own count is subject to the same silence the count exists to measure.

**Determinism has still caught none of the fifty-one.** Nor did any mutation gate catch this one: it
was caught by reading a gate's output for a tick that was absent. **The absent success line is a
signal, and no rule in this project names it.**

## Does `driver_only` still cover nothing provably? **YES. Unchanged.**

Said once more because it is the sentence a YES verdict would have to contradict:

**`driver_only` installs nothing, discloses that it installs nothing, and covers nothing provably.**
Its `omitted_extensions` reason for `compaction_ai` is unchanged and still correct in every clause,
including the four independent barriers of which `on_budget_plan`'s alone is sufficient. Nothing in
this item touched it, and the name gate does not turn on it — **the oracle row does.**

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 225 pass / 17 fail of 242 files.** The
  failing set matches the expected seventeen **member for member**: 7 `TC_ARITY_001` smoke scripts,
  the sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture.
  Stable across B4, C1, C3, C5 and now C4. `bfs` did not abort — S13's command is correct as
  corrected, and this is the first item to run it since the correction.
- **`make dst` — EXIT 2, with the SAME TWO red targets as B4, C1, C3 and C5:** `test_coverage` and
  `test_coverage_selftest`, both pre-existing, attributed by B2a to module resolution in `ailang
  test`. Every other target passes, including `event_vocabulary`, **which now genuinely passes rather
  than reporting a pass.** 805 ✓ rows — **not compared to C5's 757**, because this run adds a tick
  the previous methodology never printed and quoting a delta across two measurements would be
  inventing a comparison. The comparable claim is the red target set, which is identical.
- **`make event_vocabulary` — exit 0**, and exit 2 under the restored-literal mutant.

## Corrections owed to the plan

1. **Add the absent-tick rule.** A recipe that prints a success marker for a check can fail by
   printing *nothing*, and no rule in this project names the missing line as a signal. Every
   mutation-testing rule here (S1, S7, S16) asks what turns red; this defect turned nothing red and
   printed one fewer line. **Suggested: S19 — "a gate's success markers are an inventory; a missing
   tick is a failure report."**
2. **`cmd > /dev/null && echo "✓"` discards the status in non-terminal position under `set -e`, and
   is safe in terminal position.** This is why it survived seventeen sites and eight items. Any
   recipe that reports per-file ticks should use checked commands. Belongs beside S13.
3. **The plan's WI-C4 text needs the NO branch.** See planning defect 3 above.
4. **The oracle row's producer was never scheduled** (planning defect 1) — the single most consequential
   correction here, because it explains why five items tracked the install instead.
5. **The host-env poison pair has no owner** (planning defect 2).
6. **S15 keeps earning itself: three stale counts this item, and the handoff propagated one of them
   as fact.** A number in a comment that nothing checks is not merely stale — it gets quoted forward
   into handoffs and read as measurement. This is the third consecutive item to carry the class.

## Deliberately not done

- **Closing the D6.4 register.** Out of scope by the handoff and correctly so: twelve of the thirteen
  are driver changes with their own red surface. **This item identifies it; it does not do it.**
- **Making the four fault classes reachable.** The `ScriptedStep` error channel is named, unblocked
  and not built here.
- **The env/FS routing** for `resolve_context_limit`.
- **The `on_budget_plan` ABI change** and everything gated on it: compose's install, its eight clock
  reads, `proc_exec`/`env_get` widening.
- **Wiring the seeded runners through `execution_of`**; the extension bridge's emission channel; the
  `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds. Unchanged, still owed.
- **THE NAME.** No target adopted "DST" or "simulation". Seven consecutive items, and this is the
  first with a run table behind the refusal.
