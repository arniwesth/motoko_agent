# 2026-08-03 Cluster 8: WI-A13 stage 2 — discovery against `driver_only`

## Context

Branch: `arniwesth/mot-51-execute-wi-a13`

Session span: `c3b9d99` → `3320d8a`, **3 commits**, two of them production source. Input was
`HANDOFF-execute-a13-stage-2-discovery.md`, executed cold against HEAD. Eighth code session of
project 009, following clusters 1, 4, 6, 3, 2, 5 and 7.

Re-grounding first, as the handoff instructed: `git diff d2b8e4d..HEAD -- src packages scripts
Makefile` was **empty**, so the handoff's verified-input list held without re-measurement.

**Partial completion at a clean stage boundary**, as cluster 7 was. Nothing half-built carried across
the stop.

| | |
|---|---|
| Stage 1 — types + pure structural validator | landed (cluster 7) |
| Stage 2 — discovery against `driver_only` | **landed, green** |
| Stage 3 — strict replay | not started |
| Stage 4 — regression replay + generator canary | not started |
| Stage 5 — D8 persistence obligations | not started |

## What landed

| Commit | Item | Gate |
|---|---|---|
| `5f66c01` | **leaf split** — D2's interaction vocabulary into a std-only module | `make execution_program` |
| `8b0d605` | **stage 2** — the recorder, the two-sided checker, and everything it forced | `make discovery` |
| `3320d8a` | execution report + four corrections | plan, ADR |

New files: `src/core/dst_interaction.ail` (404), `src/core/dst_discovery.ail` (554),
`scripts/dst/discovery_dst.ail` (754).

`make discovery` is wired into the `dst` aggregate. **`make dst` exits 0**, read as an exit status
per cluster 7's process amendment. `make check_core` exits 0.

## The order the work actually took, and why it inverted the handoff's

The handoff prescribed provider → tool → approval → env. The build followed it, but the **assertion**
had to be written across all five classes at once, because the two-sided check is one comparison
function (`class_balance`) applied per class. Writing it per class in sequence would have produced
five comparison sites and five chances for one of them to be graded against the wrong witness — which
is exactly the defect the `deny` scenario later turned out to catch.

**S1 was honoured as stated**: `src/core/dst_discovery.ail` was written, unit-tested against its own
fixtures (10 tests, including a negative control and both over-recording directions), and only then
was the recorder built. The "red before the recorder exists" demonstration is preserved permanently
in the suite as **axis C** — every scenario is also run through the NON-recording adapters and must
come out red, so a future refactor cannot turn the checker into a tautology.

## The second direction, which no handoff named

The handoff's table named under-recording (completeness) and left the other cell blank with an
instruction to fill it. Filled:

| Direction | Failure | Assertion |
|---|---|---|
| Under-recording | the recorder drops a class | `discovery-under-recorded` |
| Over-recording | the recorder logs a request the driver never made | `discovery-over-recorded` |

Both are **the two arms of one `if`** in `class_balance`, deliberately: writing them as two predicates
is the shape that lets one be deleted, forgotten, or never written. Env gets the same treatment in
`env_balance`.

## The S1 result: three silent sites, and the third is in the assertion itself

**Sites sixteen, seventeen and eighteen where two implementations type-check and the wrong one is
silent. Determinism has now caught none of eighteen across eight clusters.**

### 16. `session_policy_init` discarded its successor world

A12 threaded its four env reads correctly *within* the function, then discarded the successor. Its
own comment anticipated this stage — *"each read still takes the PREVIOUS read's successor, so that
when A13 starts recording reads the order is already right and nothing has to be re-threaded."*

The ordering was right; the **discard** was not. Once a read appends to the world's log the successor
is no longer the same world, and dropping it dropped all four reads — a quarter of the driver's env
surface, on the one class with no runtime witness.

**Caught by the completeness assertion, and measured rather than asserted**: restoring A12's discard
produces four `discovery-env-read-under-recorded` findings, one per key. Nothing else saw it — the log
stayed internally consistent, dense, perfectly reproducible, and a valid `ExecutionProgram`.

### 17. `OutcomeMissing` on an end-of-input approval read

Stage 1 read D2's `value_or_missing` as environment-only and wrote a validator rule rejecting a
`missing` status on every other class. Stage 2's recorder records an eof approval read as `missing`.
Both readings type-check:

- **A. missing is ENV-ONLY.** An eof approval must then record `OutcomeOk` with an empty payload,
  which is indistinguishable from an operator who typed an empty line. A12 built `ApprovalInput.eof`
  precisely to keep those apart and the driver's policy *branches* on the difference — so reading A
  makes a class of run unreplayable.
- **B. missing means THE WORLD HAD NO VALUE TO SERVE**, equally true of an absent env key and a
  drained approval queue.

**B taken**, both readings written into `validate_outcome`, rule left closed for the other five
classes. The fixture is a tenth interaction in stage 1's negative control; reverting to reading A
turns that control red, which is the only way reading A is visible at all.

### 18. The approval witness counted the wrong thing — an OVER-REJECTION

The approval witness was the `world.approvals` cursor delta. That measures **answers consumed**, not
**reads performed**, and the two diverge the instant a queue runs dry: three tool calls against a
one-entry queue make three approval reads and move the cursor by one. **A correct recorder was
reported as over-recording.**

Cluster 7's result reproduced inside the checker built from it: *the assertion built to catch
over-recording was itself over-rejecting.* Fixed by splitting the witness — `approval_reads` from the
driver's tool-role messages, and the cursor delta demoted to what it can actually witness, checked
exactly against the recorded approvals whose outcome is not `missing`. Cluster 7 rated this witness
"Medium"; that rating was right, and the witness is now exact.

### What found 17 and 18, and the generalization

Both were invisible to the first two scenarios **for one structural reason**: `approve` and `deny`
each queue exactly as many approvals as they consume, so "reads performed" and "answers consumed" are
equal in both, and any confusion between them is hidden.

The `eof` scenario — three tool calls, **one** queued answer — makes `tool_dispatches=1`,
`approval_reads=3`, `approvals_consumed=1` pairwise distinct.

> **A fixture whose quantities are all equal cannot distinguish which quantity a check is reading.**
> The negative control must contain a case where every quantity the assertion consumes takes a
> *different* value. Equal counts are the fixture equivalent of a one-sided assertion set.

Recommended for the meta-decision file alongside cluster 7's rule, which it specializes.

### A fourth, smaller result: a fixture's justification is itself a claim

The `deny` scenario's header originally claimed it caught a recorder logging an approval as a tool
interaction. **False** — the approval balance catches that in both scenarios; introducing the mutation
showed it. What `deny` uniquely catches is a **miswiring of the checker**: grade the tool balance
against `approvals_consumed` instead of `tool_dispatches`, one line between two adjacent fields, and
`approve` passes while `deny` fails. Verified by introducing exactly that miswiring. The comment now
records the measured reason.

## The witnesses, and the one that cannot be read from AILANG

Two authors, two records, one execution — the property that makes this an oracle rather than the
recorder grading itself.

| Class | Witness | Where consumed |
|---|---|---|
| Provider | `ProviderCallPrepared` in the RETURNED trace | in-script |
| Provider (content) | its `step` field vs the recorded identity's step | in-script |
| Tool | tool-result messages; call ids compared positionally | in-script |
| **Tool (strong)** | **wire `v2_tool_dispatch_start`, emitted BEFORE the port calls** | **`make discovery`** |
| Approval | tool-role message count; cursor delta as an exact second check | in-script |
| Clock | `world.clock_ms` delta == sum of recorded advances, exactly | in-script |
| Env | source-derived key set **with multiplicities** | `make discovery` |

**The strongest witness cannot be read from inside AILANG.** `V2ToolDispatchStart` is emitted BEFORE
the port calls, which makes it the one tool witness that exists whether or not the port was reached —
but it goes to the wire through `ledger_emit` and is never appended to the returned trace (cluster 4
measured the same emit/append imbalance, 37 vs 15). `make discovery` therefore runs a dedicated
`--entry wire_witness` performing exactly ONE driver run, captures the JSONL, and compares it against
the census that run printed. One run, one census, exact equality, no multiplier to keep in sync.

**Identity CONTENT, not only counts.** Both content comparisons were demonstrated red under deliberate
recorder mutation (forcing step 0; forcing a fixed call id). This matters because the provider `step`
is the recorder's one *decided* binding — `Ports.model_step` never receives `step_idx`, and widening
it was forbidden — so it is derived from log position, and four provider interactions all carrying
step 0 are still four provider interactions to a count check.

## Correction 1 — env completeness needs MULTIPLICITY, not presence

Cluster 7's recommendation to use a source-derived key set was right and shipped. But **presence alone
is insufficient, and the first version of this check was presence-only.** A recorder that logs the
first read of a key and drops later ones satisfies it — and the driver reads `MOTOKO_TOOL_TIMEOUT_MS`
once per native dispatch, so such a recorder loses two of three reads in `approve` while looking
complete. Nothing else would have seen it.

The counts remain **provenance** evidence, with one exception: `MOTOKO_TOOL_TIMEOUT_MS`'s expected
count is expressed in terms of the independently *witnessed* dispatch count, anchoring the one
repeated env read to a runtime witness. Cluster 7's correction 2 — six classes with runtime evidence,
one with provenance evidence, never summed into one number — stands unchanged.

## Correction 2 — the `.env_get` derivation caught its own first regex

The gate re-derives the env key set from the driver's call sites. Its first version anchored on
`ports.env_get(` and **silently missed** `MOTOKO_CAPTURE_FAILED_PAYLOAD`, which goes through
`st.provider.env_get(`. The derivation reported the disagreement on its first run — the case for
deriving rather than declaring, made by the derivation, on itself.

Now anchored to `.env_get(<world>, "KEY"` with the receiver unanchored and a key literal required, so
the extension bridge's closure (key supplied by an extension at call time) correctly does not match.

## Correction 3 — the Makefile grep-guard audit cluster 7 asked for

Nine grep-based guards audited. One bare-token guard fixed; one deliberately left alone.

**Fixed:** `make terminal_trace` counted `'{ result:'` over `session.ail` and required exactly 1. It
counted comment lines, so `session.ail` carried a standing obligation to *circumlocute around its own
guard's pattern in prose* — the identical landmine that kept `make world_state` red for two clusters.
Anchored to a record literal not preceded by a dash, which no AILANG comment line can satisfy.
**Verified in both directions:** 1 at HEAD, 3 against a file with two deliberately added bypassing
terminal returns in both plausible shapes. No coverage lost; the circumlocution obligation is retired.

**Left alone:** `fault_catalogue`'s physical-fault tripwire greps prose terms and excludes
`dst_fault_catalogue.ail` by name. It is a tripwire on *intent*, not syntax, so a syntactic anchor
does not apply — but its exclusion list is a maintenance obligation that grows with every artifact
documenting the exclusion. A14/A15 should know.

The other seven are already anchored to line-start structural forms or call forms.

## Correction 4 — A5's table anchors by LINE NUMBER, and a no-op re-measurement cost a version bump

Stage 2 inserted lines above four attributed clock sites. That re-measured A5's table, changed its
content hash, and cascaded to five artifacts: the Makefile anchors, `dst_attribution_table`,
`dst_profile`'s unit tests, `profile_definition_dst`'s fixtures, and `driver_only` — which per D4 had
to be **re-issued as v2**, the remedy `driver_only_dst` states at its own point of failure.

**Every guard fired loudly with an exact expectation-versus-actual.** They worked. But **the claim did
not change** — same seven sites, effects, routed flags and reviewers; only coordinates moved. The hash
cannot distinguish a re-measurement from a correction, so a profile version bump was spent on a no-op.

Filed, not reconciled. Any cluster inserting a line into the driver above an attributed site pays
this. A14/A15 should decide whether a coordinate-independent anchor (symbol name plus a content digest
of the enclosing function) is worth building before the name gate.

A stale transcription surfaced alongside: `test_manifest_reads_the_vocabulary_version` asserted
`profile_version == "1"` as a literal — a transcription inside the test whose stated subject is "read,
not transcribed". Now reads `driver_only_version()`.

## The leaf split, and the alternative that was rejected

`WorldState` has to name `Interaction`, and `ports.ail` cannot import `dst_program` — that module
names `ExecutionManifest` and would drag the 1559-line `dst_profile` closure into the production
driver's import graph.

The obvious alternative was a second, flatter "recorded request" record in `ports.ail`, projected into
`Interaction` by the discovery module. **Rejected deliberately:** two representations of one fact with
a hand-written projection between them is the exact shape of the eighteen silent defects this project
has found, and the projection would have been written by the same code whose completeness stage 2 puts
under test. One representation, moved down into a module importing nothing but std.

**No signature in `Ports` changed**, exactly as A12 predicted at `ports.ail`'s env comment.

## Sizing: S6 again, second term dominant again, ~3× stage 1

**Round trips: 2 compiler (both loud), 4 gate (all loud), 3 silent.**

- **Compiler.** A record literal after `=>` parses as a block on this pin (`({…}) :: rest` needs the
  parens). And a local `let step = …` does **not** shadow `import std/ai (step)` — the reference
  resolves to the imported function and fails unification against an `int` field, with a message
  pointing at the type rather than the shadowing. Both noted in-source.
- **Gate.** The env-derivation regex, the attribution anchors, the `driver_only` re-issue cascade, the
  stale `"1"`. Each arrived with an exact expectation and actual.
- **Silent.** Sites 16, 17, 18. **None found by a gate**; all three found by writing a fixture for a
  case the existing scenarios could not reach. This is where the session's real time went — S5's
  "budget silent defects at the cost of noticing them", where the cost is deciding to go looking.

**Grounding was again a little over half the session** before a line could be written: the parent
handoff, cluster 7's report, the plan's standing rules, and the exports of `dst_program`, `ports`,
`stub_step`, `session`, `dst_profile`, `dst_driver_only`, `dst_fault_catalogue`, plus
`world_state_probe` as the precedent for driving the driver. S6's first term, over more input
artifacts than stage 1 had.

**S6's second term — generalized by cluster 7 to *any fact that cannot be read and must be decided* —
is again where the whole risk lived.** Stage 2 had **three** recorded bindings against stage 1's one:

1. **The provider identity's `step`**, derived from log position because the port never receives
   `step_idx`. Checked against the driver's own values; guard demonstrated red.
2. **The `OutcomeMissing` reading** (site 17).
3. **The approval deadline.** D2 gives `ExpectApproval` a deadline; the driver's approval channel
   carries none (`DenyAfterTimeout` is a decision, not a duration). 0 recorded, matching what
   `ToolInvocation.timeout_ms` already establishes for the tool class. **Declared gap:** until an
   approval deadline is routed, D3's `approval_deadline_exceeded` cannot be reached by a discovered
   program, and D11's counters must show it *unreached* rather than waived.

**Cost against stage 1: roughly 3×.** Cluster 7's warning not to extrapolate stage 1 was correct — the
driver wiring is where the time went, as S3 predicts and as A12 measured on nominally identical scope.
**No sixth model needed:** recorded bindings went 1 → 3 and cost went ~3×, tracking better than any
measure of size.

**Judgement ratio, split** (cluster 5's rule):

- **Machinery — the checker and the recording seams: ~30%.** D2 fixes the classes and identities
  tightly and A12 left the seams in the shape that made each recorder one wrapper. Undetermined: the
  three recorded bindings, and the decision to make the check two-sided at all, which no artifact
  asked for.
- **Content — the scenarios: ~95%.** *Which* three scenarios exist is discovered, not specified. The
  single most consequential decision in this commit is content: the `eof` scenario, without which two
  of the three silent sites ship. `deny` is second, and its value turned out to differ from the one
  first written down.

## For the next session (stage 3)

Unblocked. `ExecutionProgram`s are now produced from real runs and pass stage 1's validator;
`RecordingWorld` and `TracedSessionResult.world` give the seam in both directions; `driver_only` is v2
and loads clean.

1. **`routing_violation_at`'s call site is still unlanded.** Stage 2 establishes the profile only as a
   manifest on the program; the dead rider remains, exactly as the plan says.
2. **`world_state_of` is stage 3's**, and design note 3 in `dst_program` is the constraint: the
   program deliberately does not carry the provider script, approval queue or tool queue — they are
   projections of the interaction list.
3. **The message-derived witnesses are empty on the `Err` path.** `discovery_dst` asserts each scenario
   reached its terminator so this fails loudly rather than degrading to a vacuous check. Stage 3 wants
   failure-path scenarios and will need a witness that survives `Err` — the ledger trace does; the
   returned message list does not.

## Traps confirmed

- The parallel `ailang check` closure tool was rebuilt before editing, per six prior clusters. **1.7 s**
  over the 13-module closure.
- **Read `make dst`'s exit status, not its output** — followed throughout.
- **New:** do not run other `make` targets concurrently with `make dst`. Two runs in this session were
  corrupted that way before the discipline was applied; the log truncates mid-target and looks like a
  failure that is not there.
- Cluster 7's guard-anchoring correction was applied to a new guard from the start (the env
  derivation) and retroactively to one existing guard (`terminal_trace`).
- Pin is v0.26.0, Makefile-guarded. No cache-clearing needed; no contradicting type errors appeared.
- PR #103 not merged.
