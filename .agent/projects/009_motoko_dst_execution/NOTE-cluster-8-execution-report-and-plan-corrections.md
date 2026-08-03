# Cluster 8 execution report — WI-A13 stage 2, and four corrections

Eighth calibration run. **Partial completion at a clean stage boundary**, as cluster 7 was. Stage 2
of WI-A13's five is landed, green, and committed. Stages 3–5 are not started and nothing half-built
is carried across the stop.

Commits:

- `5f66c01` refactor(A13): split D2's interaction vocabulary into a std-only leaf module
- `8b0d605` feat(A13): stage 2 — discovery against driver_only, graded in both directions

**`make dst`: exit 0.** Read as an exit status, not a scan of output, per cluster 7's process
amendment. `make check_core`: exit 0.

---

## What landed

**`src/core/dst_interaction.ail`** — D2's interaction vocabulary, moved down out of `dst_program` so
that `ports.ail` can name `Interaction` without dragging `dst_profile` into the production driver's
import graph. Imports nothing but std.

**`src/core/dst_discovery.ail`** — the two-sided checker, its findings, the source-derived env key
set, and the per-class census. Written before the recorder existed.

**`src/core/ports.ail`** — `WorldState.log`, `record_interaction`, and four recording seams that WRAP
the deterministic ones rather than reimplementing them. **No signature in `Ports` changed**, exactly
as A12 predicted at `ports.ail`'s env comment.

**`src/core/test/stub_step.ail`** — `RecordingWorld(WorldState)` and `recording_ports`.

**`src/core/session.ail`** — `TracedSessionResult.world`, the `ported_provider` arm, and
`session_policy_init` returning its successor.

**`scripts/dst/discovery_dst.ail`** and **`make discovery`**, wired into the `dst` aggregate. Three
scenarios × (two-sided balance, two identity-content comparisons, eight mutation rows, a vacuity
control, determinism, and stage 1's validator over the recorded log) — 16 checks per scenario, 48 in
all, plus the wire comparison and the env derivation in the make target.

---

## The S1 result — three sites, and the third is in the assertion itself

**Sites sixteen, seventeen and eighteen where two implementations type-check and the wrong one is
silent. Determinism still catches none — now zero for eighteen across eight clusters.**

### 16. `session_policy_init` discarded its successor world

A12 threaded its four env reads correctly *within* the function and then discarded the successor,
reasoning that policy init runs once and `scripted_env` returns the world unchanged. Its own comment
anticipated this stage: *"each read still takes the PREVIOUS read's successor, so that when A13
starts recording reads the order is already right and nothing has to be re-threaded."*

The ordering was right. The **discard** was not. Once a read appends to the world's log the successor
is no longer the same world, and dropping it dropped all four reads — a quarter of the driver's env
surface, on a path with no runtime witness at all.

**What caught it:** the completeness assertion. **Measured, not asserted** — restoring A12's discard
produces four `discovery-env-read-under-recorded` findings, one per key. **What did not catch it:**
everything else. The log stayed internally consistent, dense, perfectly reproducible, and a valid
`ExecutionProgram`.

### 17. `OutcomeMissing` on an end-of-input approval read

Stage 1 read D2's `value_or_missing` as environment-only, and wrote a validator rule that rejects a
`missing` status on any other class. Stage 2's recorder records an eof approval read as `missing`.
Both type-check. The two readings:

- **A. missing is ENV-ONLY.** An eof approval must then record `OutcomeOk` with an empty payload —
  making it indistinguishable from an operator who typed an empty line. A12 created
  `ApprovalInput.eof` precisely to keep those apart, and the driver's policy *branches* on the
  difference. Reading A makes a class of run unreplayable.
- **B. missing means THE WORLD HAD NO VALUE TO SERVE**, equally true of an absent env key and a
  drained approval queue.

**B taken**, both written down in `validate_outcome`, and the rule stays closed for the other five
classes. The fixture is a tenth interaction in stage 1's negative control; reverting to reading A
turns that control red, which is the only way reading A is visible at all.

### 18. The approval witness counted the wrong thing — and this one is an OVER-REJECTION

The approval witness was `world.approvals` cursor delta. That measures **answers consumed**, not
**reads performed**, and the two diverge the moment a queue runs dry: three tool calls against a
one-entry queue make three approval reads and move the cursor by one. A **correct** recorder was
reported as over-recording.

This is cluster 7's result reproduced inside this stage's own checker, and it is worth stating
plainly: **the assertion built to catch over-recording was itself over-rejecting.** The fix splits
the witness — `approval_reads` from the driver's tool-role messages, and the cursor delta demoted to
what it can actually witness, checked exactly against the recorded approvals whose outcome is not
`missing`. Cluster 7 rated this witness "Medium"; this is exactly why, and it is now exact.

### What found 17 and 18: one fixture, and it is the predicted kind

Both were invisible to the `approve` and `deny` scenarios **for the same structural reason** — each
queues exactly as many approvals as it consumes, so "reads performed" and "answers consumed" are
equal in both and any confusion between them is hidden.

The `eof` scenario — three tool calls, **one** queued answer — makes `tool_dispatches=1`,
`approval_reads=3` and `approvals_consumed=1` pairwise distinct. That is the whole mechanism. It is
the third distinct time cluster 7's rule has predicted where to look, and the generalisation earns a
sharper form:

> **A fixture whose quantities are all equal cannot distinguish which quantity a check is reading.**
> The negative control must contain a case where every quantity the assertion consumes takes a
> *different* value. Equal counts are the fixture equivalent of a one-sided assertion set.

### A fourth, smaller one: the scenario pair's justification was wrong, and measuring it fixed the claim

The `deny` scenario's header originally claimed it was needed to catch a recorder logging an approval
as a tool interaction. **That claim is false** — the approval balance catches that in both scenarios.
Deliberately introducing the mutation showed it.

What `deny` uniquely catches is a **miswiring of the checker**: grade the tool balance against
`approvals_consumed` instead of `tool_dispatches` — one line, two adjacent fields — and `approve`
passes while `deny` fails. Verified by introducing exactly that. The comment now says the measured
thing. Worth noting as a habit: **a fixture's stated justification is itself a claim, and it is cheap
to test.**

---

## Correction 1 — the env class's completeness needs MULTIPLICITY, not presence

Cluster 7 recommended asserting the env class against a source-derived key set. That is right and it
is what shipped, but **presence alone is not enough and the first version of this check was
presence-only.** A recorder that logs the first read of a key and drops later ones satisfies it — and
the driver reads `MOTOKO_TOOL_TIMEOUT_MS` once per native tool dispatch, so that recorder loses two
of three reads in the `approve` scenario while looking complete. The env class has no runtime
witness, so nothing else would have seen it.

The counts are still **provenance** evidence — except `MOTOKO_TOOL_TIMEOUT_MS`, whose expected count
is expressed in terms of the independently *witnessed* dispatch count. That one repeated env read is
therefore anchored to a runtime witness even though the read itself has none. **A13's report and
D11's counters must carry six classes with runtime evidence and one with provenance evidence**, per
cluster 7's correction 2, which stands unchanged.

---

## Correction 2 — the `.env_get` derivation caught its own first regex, which is the argument for it

The `make discovery` step re-derives the env key set from the driver's call sites. Its first version
anchored on `ports.env_get(` and **silently missed** `session.ail`'s `MOTOKO_CAPTURE_FAILED_PAYLOAD`
read, which goes through `st.provider.env_get(`. The derivation reported the disagreement on its
first run.

That is the case for deriving rather than declaring, made by the derivation, on itself. The anchor is
now the syntactic form `.env_get(<world>, "KEY"` with the receiver unanchored and a key literal
required — so the extension bridge's closure, whose key is a variable, correctly does not match.

---

## Correction 3 — the Makefile grep-guard audit (cluster 7 recommended it; here it is)

Nine grep-based guards. One was a bare-token guard and is fixed; the rest are already anchored.

| Guard | Anchor | Verdict |
|---|---|---|
| `terminal_trace`: terminal record literals | was `'{ result:'` | **FIXED** — see below |
| `world_state`: randomness | `'^import std/rand'` | anchored (cluster 7) |
| `profile_definition`: field count | awk range + `'^  [a-z_]*:'` | anchored; a comment cannot match |
| `profile_coverage`: hook count | awk range + `'^  on_'` | anchored |
| `event_vocabulary`: variants | awk range + `'^  [|=]'` | anchored |
| `event_vocabulary`: goldens | `'golden\([A-Za-z0-9]+\('` | anchored to a call form |
| `event_vocabulary`: rows | `'variant: "'` inside an awk range | weak but function-scoped; noted, not changed |
| `fault_catalogue`: physical-fault tripwire | bare prose terms + a file exclusion | **correctly not syntactic** — see below |
| `discovery`: env keys | `'\.env_get\(…, "KEY"'` | anchored (new) |

**The fix.** `make terminal_trace` counted `'{ result:'` over `session.ail` and required exactly 1.
It counted comment lines, so `session.ail` carried a standing obligation to *circumlocute around its
own guard's pattern in prose* — the identical landmine that kept `make world_state` red for two
clusters. Anchored to a record literal not preceded by a dash, which no AILANG comment line can
satisfy. **Verified in both directions:** 1 at HEAD, and 3 against a file with two deliberately added
bypassing terminal returns in both plausible shapes, so the tightening costs no coverage. The
circumlocution obligation is retired.

**The one that should stay as it is.** `fault_catalogue`'s physical-fault tripwire greps prose terms
(`fsync`, `write-ahead log`, …) and excludes `dst_fault_catalogue.ail` by name. It is a tripwire on
*intent*, not syntax, so a syntactic anchor does not apply — but its exclusion list is a maintenance
obligation that grows with every artifact that documents the exclusion. Worth A14/A15 knowing.

---

## Correction 4 — A5's table anchors sites by LINE NUMBER, and that is fragile in a way worth naming

Stage 2 inserted lines into `session.ail` and `stub_step.ail` above four attributed clock sites. That
re-measured A5's table, changed its content hash, and cascaded to five artifacts: the Makefile
anchors, `dst_attribution_table`, `dst_profile`'s unit tests, `profile_definition_dst`'s fixtures,
and `driver_only` — which per D4 had to be **re-issued as v2**, the remedy `driver_only_dst` states
at its own point of failure.

**Every one of these fired loudly with an exact expectation-versus-actual.** The guards worked. But:
**the claim did not change.** Same seven sites, same effects, same routed flags, same reviewers; only
the coordinates moved. The hash cannot distinguish a re-measurement from a correction, so a profile
version bump is spent on a no-op edit.

Treating both as a re-issue is the safe direction and the header already chose it ("that cost IS the
rule"). **This is filed, not reconciled:** any cluster that inserts a line into the driver above an
attributed site pays this, and A14/A15 should decide whether a coordinate-independent anchor (a
symbol name plus a content digest of the enclosing function) is worth building before the name gate.

One stale transcription surfaced with it: `test_manifest_reads_the_vocabulary_version` asserted
`profile_version == "1"` as a literal — a transcription inside the test whose stated subject is
"read, not transcribed". Now reads `driver_only_version()`.

---

## Sizing — S6 still, second term dominant again, and stage 2 cost ~3× stage 1

**S6 (composition), with its generalised second term, and it predicted the risk location for the
second cluster running.**

**Round trips: 2 compiler, both loud; 4 gate, all loud; 3 silent, all found by deliberate probing.**

- **Compiler (2).** A record literal after `=>` parses as a block on this pin, so `({…}) :: rest`
  needs the parens — loud, with a line number. And a local `let step = …` does **not** shadow
  `import std/ai (step)`: the reference resolves to the imported function and fails unification
  against an `int` field. Loud, but the message (`cannot unify type constructor int with
  *types.TFunc2`) points at the type and not at the shadowing, so it cost more than its loudness
  suggests. Both are noted in-source for the next reader.
- **Gate (4).** The env-derivation regex, the attribution anchors, the `driver_only` re-issue
  cascade, the stale `"1"` transcription. Every one arrived with an exact expectation and actual.
- **Silent (3).** Sites 16, 17, 18. **None was found by a gate; all three were found by writing a
  fixture for a case the existing scenarios could not reach.** This is where the session's real time
  went, and it is where S5's "budget silent defects at the cost of noticing them" applies — the cost
  is not the fix, it is deciding to go looking.

**Grounding was again a little over half the session before a line could be written**: the parent
handoff, cluster 7's report, the plan's standing rules, and the exports of `dst_program`, `ports`,
`stub_step`, `session`, `dst_profile`, `dst_driver_only`, `dst_fault_catalogue`, plus
`world_state_probe` as the precedent for driving the driver. That is S6's first term behaving as A10
measured it, over more input artifacts than stage 1 had.

**S6's second term, generalised by cluster 7 to *any fact that cannot be read and must be decided*,
is again where the whole risk lived.** Stage 2 had **three** such bindings, against stage 1's one:

1. **The provider identity's `step`.** `Ports.model_step` does not receive `step_idx` and widening it
   was the one thing this stage was told not to do, so the step is derived from the provider class's
   own position in the log. **This is the binding a count-based check cannot see** — four provider
   interactions all carrying step 0 are still four provider interactions. It is checked against the
   driver's own `ProviderCallPrepared.step` values, and the guard was demonstrated red by forcing the
   recorder to record 0.
2. **The `OutcomeMissing` reading** (site 17).
3. **The approval deadline.** D2 gives `ExpectApproval` a deadline and the driver's approval channel
   carries none — `DenyAfterTimeout` is a decision, not a duration. 0 is recorded, matching what
   `ToolInvocation.timeout_ms` already establishes for the tool class. **Declared gap, not a solved
   problem:** until an approval deadline is routed, D3's `approval_deadline_exceeded` class cannot be
   reached by a discovered program, and D11's counters must show it *unreached* rather than waived.

**Cost against stage 1: roughly 3×.** Cluster 7 warned not to extrapolate stage 1's cost and that
warning was correct — the driver wiring is where the time went, exactly as S3 predicts and as A12
measured on nominally identical scope. **No sixth model is needed.** S6 with cluster 7's generalised
second term priced this item correctly, and the count of recorded bindings (1 → 3) tracked the cost
ratio better than any measure of size.

**Judgement ratio, split** (cluster 5's rule):

- **Machinery — the checker and the recording seams: ~30%.** D2 fixes the classes and identities
  tightly, and A12 left the seams in the shape that made the recorders one wrapper each. What was not
  determined: the three recorded bindings above, and the decision to make the check two-sided at all,
  which no artifact asked for.
- **Content — the scenarios: ~95%.** *Which* three scenarios exist is discovered, not specified, and
  the single most consequential decision in this commit is content: the `eof` scenario, without which
  two of the three silent sites ship. `deny` is second, and its value turned out to be different from
  the one first written down.

A combined figure would again read as "the spec was vague". It was not.

---

## For stage 3, and what is unblocked

**Unblocked.** Stage 3 (strict replay) has what it needs: `ExecutionProgram`s are now produced from
real runs and pass stage 1's validator; `RecordingWorld` and `TracedSessionResult.world` give it the
seam in both directions; `driver_only` is v2 and loads clean.

Three things stage 3 should know:

1. **`routing_violation_at`'s call site is still unlanded.** Stage 2 establishes the profile only as
   a manifest on the program; the dead rider remains, exactly as the plan says.
2. **`world_state_of` — reconstituting a world from a program — is stage 3's, and design note 3 in
   `dst_program` is the constraint it must satisfy.** The program deliberately does not carry the
   provider script, approval queue or tool queue; they are projections of the interaction list.
3. **The message-derived witnesses are empty on the `Err` path.** `discovery_dst` asserts each
   scenario reached its terminator so this fails loudly rather than degrading to a vacuous check.
   Stage 3 will want failure-path scenarios, and it will need a witness that survives `Err` — the
   ledger trace does; the returned message list does not.

**Tooling.** The parallel `ailang check` closure tool runs in ~1.7 s over the 13-module closure;
rebuild it before editing, per six prior clusters. `make dst` takes several minutes — **read its exit
status, not its output**, and do not run other `make` targets concurrently with it (two runs in this
session were corrupted that way before the discipline was applied).
