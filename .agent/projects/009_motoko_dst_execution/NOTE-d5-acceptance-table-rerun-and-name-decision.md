# WI-D5 — the acceptance table, re-run row by row. **VERDICT: YES. THE NAME IS ADOPTED.**

Twenty-ninth calibration run. Written against HEAD `5ecd858`, branch
`arniwesth/mot-67-wi-d4-restore-the-three-targets-d3-reddened`.

## Window

**~25 minutes** wall-clock: `2026-08-06T06:51Z` → `2026-08-06T07:16Z`. Two measurements dominate it:
the cache-cold sweep (`06:53:18Z` → `06:56:36Z`, 3m18s) and `make dst` in full (`06:57:09Z` →
`07:07:05Z`, 9m56s).

## Grounding

**Clean, and D4's source work is committed.** The handoff flagged that D4's 16 modified files were
uncommitted at the time of writing, and that a verdict measured against an uncommitted tree describes
something no revision records. **They are committed** — `f2ca448` ("Impelmented"), the exact 16-file
set the handoff described, 736 insertions. `git status` is clean at `5ecd858`. Nothing was resolved
silently because nothing needed resolving.

**S9's concurrency check: no other session is running a gate.** One live `ailang` process exists in
this tree — a `src/core/supervisor.ail` agent run, 1d09h elapsed against 447s CPU, holding no
`.ailang/cache` or `/tmp/*.out` descriptors. It is an idle agent session, not a gate. Three other
`make claude` shells are days old. **D4 found a concurrent `make dst` and every measurement would
have been poisoned silently; this check is now part of the procedure.**

**Caches: 8 live `.ailang/cache` directories cleared**, `~/.ailang/cache/registry` left alone and
verified intact. `/tmp/corpus_pr.out`, `/tmp/latency_pair.out`, `/tmp/corpus_rot.out` and
`/tmp/corpus_job.out` were **deleted before the run**, so every artifact read below was written by
this item's own `make dst`. **Per S19 the class-coverage rows are read from `/tmp/corpus_pr.out`
itself, not from the make transcript**, which truncates to `tail -40` on failure and misled two
sessions in a row.

## D10's two conditions

**Condition 2 — project-007's definition/taxonomy ADR is accepted. CONFIRMED, not re-litigated.**
`007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:4` reads
`Status: **Accepted 2026-07-26.**` Satisfied for six weeks.

**Condition 1 — the acceptance test passes for a documented baseline profile.** It does. The profile
is **`driver_only/10` under execution manifest `driver_only/3`**, printed by the gate on every run.
D10 requires every report to name the profile; this one does, and every figure below is that
profile's.

## THE VERDICT

**YES. Eleven of eleven rows hold for `driver_only/10`.** C4 found seven; D1 closed rows 4 and 11,
D2 closed row 7, D3 closed row 10, and D4 restored the evidence rows 4 and 11 rest on. **This is the
first run of the full table since C4**, and every number below was re-derived from it rather than
read forward.

**One row passes on a stated reading and I am reporting it rather than burying it — see row 7.** If a
reviewer rejects that reading, row 7 is red and this verdict is NO. It is the single interpretive
dependency in the table.

## The eleven answers

| # | Row | Verdict | Produced by |
|---|---|---|---|
| 1 | Does one seed generate an execution rather than only values? | **PASS** | `discovery` · `strict_replay` · `seeded_generator` · `execution_program` |
| 2 | Is there a modeled logical environment? | **PASS** — C4's qualification is discharged | `world_state` · A12 probe |
| 3 | Is the tested boundary honest? | **PASS — VACUOUS** in every installed-extension clause | `driver_only` v10 · `profile_coverage` · `profile_definition` · `hook_guard` |
| 4 | Do injected faults reach production recovery code? | **PASS** — one of its two waivers is bought by the empty install list | `corpus_pr` artifact · `fault_catalogue` |
| 5 | Does virtual time matter? | **PASS** — real, and **non-transferable** | `driver_only.routed_set_claim` · `world_state` Clock pair · `latency_pair` artifact |
| 6 | Is production logic under test? | **PASS** | `smoke_driver` · `terminal_trace` · `world_state` |
| 7 | Is the oracle complete? | **PASS on a stated reading** — one of its two exemptions is bought by the empty install list | `invariants` · `event_vocabulary` · `ledger_parity` · `stream_parity` |
| 8 | Are harness failures separate? | **PASS** | `strict_replay` · `world_state` poison pairs |
| 9 | Are discovery and replay stable? | **PASS** | `discovery` · `strict_replay` |
| 10 | Is hermeticity enforced? | **PASS** | `world_state` — five two-sided poison pairs |
| 11 | Is there actual search? | **PASS** | `corpus_pr` artifact · `corpus_rotating` |

### 1 — one seed generates an execution. PASS

`discovery_dst PASS`, `strict_replay_dst PASS`, `execution_program_dst PASS`. The census sequences
differ by scenario and are resolved rather than scripted — `approve` at `expect_provider=4
expect_tool=3 expect_approval=3 advance_clock=6` against `deny` at `expect_provider=4 expect_tool=0
expect_approval=3 advance_clock=3`. Zero unexpected harness failures.

**The anti-count control is the load-bearing part and it is intact after D4's re-pin.** `pairA`
(seed 132) and `pairB` (seed 12) produce **equal interaction counts (23) and different digests**
(`2144863192` vs `1372950750`), so the row cannot be satisfied by programs differing only in length.
`repeat` (seed 132 again) reproduces `pairA`'s digest exactly.

**And S20's new rows are green, which is what makes this row mean what it says.** `rich` made 111
generator choices, `pairA`/`pairB` 47 each; the bound is asserted as `== budget + 1` rather than
`<=`; and two independent guards hold — *"the counted quantity is a PROPER subset of the log — the
filter counts and excludes"* and *"the tightened bound (3) is BELOW this seed's natural trajectory
(4)"*. **Before D4 a generated trajectory was a function of the driver's config-read count; it is
now a function of the seed and the generator.**

### 2 — a modeled logical environment. PASS, and C4's qualification is discharged

Provider, typed tool execution, approval, clock, environment and logical resource state thread
through one state-threaded world with checked transitions. The A12 probe's cursor-advancement rows
are green (`advance: cursor advances`, `advance: served sequence is exactly the script`, `advance:
exactly one run_summary, and it is last`, `exhaust: cursor advances to the budget`). Runtime
randomness is honestly reported as unused — `runtime_random_draw=0` on every census, and
`runtime_random_draw [runtime-witness] witnessed=6 logged=6` where it is exercised.

**C4 passed this row "qualified — see row 10", booking the env defect against hermeticity. Row 10 is
now closed, so the qualification has no referent.** This row passes unqualified.

### 3 — the tested boundary is honest. **PASS, AND IT IS VACUOUS. Unchanged from C4, and re-decided.**

**Every clause quantifying over installed extensions is vacuously true, because `driver_only`
installs nothing.** The gate says so itself rather than leaving it to a reader:

```
✓ an empty install list cannot violate: vacuous for driver_only, binding from C5
✓ the runtime exclusion check is VACUOUS for driver_only: nothing installed,
  nothing excluded, no dispatch can violate (binding from WI-C5)
```

**The row still passes on its final clause**, which asks that a weak profile be *visible*, not that
it be strong: *"the result reports per-extension covered/excluded hook **ids**, so a profile covering
only ABI-pure no-op slots is visible as such."* `driver_only` names its omission (`compaction_ai`)
and states in one recorded paragraph exactly which four slots are coverable under neither D5
criterion and why. A reader cannot mistake this profile for a covering one.

**What is not vacuous:** the profile and manifest are named and validate against the definition they
realize (`driver_only/10` under `driver_only/3`); the routed-set claim is computed rather than
recorded; the excluded hooks and adapter/parser boundaries are listed; and `profile_coverage`'s
thirteen rejecting fixtures each go red **by their own rule** — `[coverage-floor]`,
`[unconditional-hook-excluded]`, `[covered-excluded-exhaustive]`, `[covered-excluded-disjoint]`,
`[duplicate-extension-id]`, `[unknown-hook-id]` — so the rules bind unconditionally even where they
have nothing to bind over.

**Two clauses are satisfied only by synthetic fixtures, and that is unchanged from C4.** "Dispatch to
an exclusion fails closed" is `make hook_guard`, **4 passed, 0 failed** — it asserts the excluded
hook's *body did not run*, but no profile in this tree can reach it. The per-extension hook-id
disclosure is exercised at `✓ ids: equal counts (3), distinguishable ids`, a fixture with three
extensions. **The mechanism is demonstrated; it is not exercised by the baseline.**

### 4 — injected faults reach production recovery code. **PASS**

Read from `/tmp/corpus_pr.out`, not from the transcript:

```
✓ the corpus validates against 9 expected class(es): provider_error_retryable,
    provider_error_non_retryable, provider_protocol_inconsistent_result,
    provider_partial_stream_then_error, provider_empty_terminal_response,
    ToolFailed, ToolCorrelationMismatch, ToolDeadlineExceeded, approval_denied
✓ the unreachable register is EMPTY: every required non-waived class is reached
    by SEARCH, none subtracted
✓ every expected class was OBSERVED (declared ⊆ observed)
```

**Nine of nine required non-waived classes, with nothing subtracted** — where C4 measured five of
nine against a register of four. Zero `✗` rows in the artifact.

**The row's own word is *recovery code*, not *class*, and the wire answers it independently:**

```
✓ wire witness, branch-reached: approval_denied×35 empty_stop_finalize×1
  ToolFailed×3 ToolCorrelationMismatch×4 ToolDeadlineExceeded×5
  stream_error_retry×5 provider_failure_finalize×13 malformed_arguments×7
  (against 65 executed dispatch batch(es), so neither side of the approval
  decision is unwalked)
```

Eight named production branches, every one non-zero, counted from records production code wrote
knowing nothing about the interaction log. `run_report` agrees: **9 of 11 fault classes reached and
9 of 11 named recovery branches reached**, both counters, both windows. **C4's two disagreeing
windows (9 of 11 fixture against 5 of 11 measured) now agree**, because the measured answer moved up
to the fixture's.

**Both waived classes are named with their conditions, as the row requires — and one waiver is
bought by the empty install list.** Printed by the gate:

```
extension_effect_fault: the selected D5 profile installs an extension with an
  effectful hook that issues this world request; driver_only installs none, so
  it waives this class by construction (plan P4)
```

**That waiver transfers to no other profile.** The other (`approval_deadline_exceeded`) is waived on
a genuine production-policy condition and is unrelated to the install list.

**One qualification carried forward from D1 and re-measured here:**
`provider_empty_terminal_response` is reached by a **constructed** member, not by a seed — the gate
holds `empty_stop_finalize` to **exactly 1** so that a seed starting to reach it must be recorded
rather than absorbed. Nine of nine is **eight by search and one by construction**, and the row does
not require otherwise.

### 5 — virtual time matters. **PASS — real, and non-transferable**

The routed-set claim is **computed, not recorded**:

```
✓ routed-set claim is a partition of the table: 7 reachable = 6 routed + 1 declared-unrouted
      reachable core sites: 7   routed: 6   declared unrouted: 1
```

The one unrouted site is the live adapter, ambient by design, and its containment is **evidenced
rather than asserted** by the Clock poison pair (below). The rejecting fixtures hold in both
directions — an undeclared unrouted site, a declared site with no instrument, and a declaration for a
site that is no longer reachable-and-unrouted are each rejected by their own rule.

The latency pair holds, read from `/tmp/latency_pair.out`: the two runs differ **only** in
`duration_ms` (40 vs 3000), the declared deadline lies strictly between them (40 < 1000 < 3000), the
fast half completes and the slow half records `ToolDeadlineExceeded`, the clocks differ by exactly
the latency difference (2960 == 2960), and a zero-deadline control completes on the same 3000ms
latency. `✓ wire witness: 4 of 9 native_tool_results carry ToolDeadlineExceeded (the slow halves,
and only those)` — the gate refuses both the zero case and the all-faulted case. No OS timeout is
invoked.

**The caveat is about transfer, not validity, and it is the same one C4 recorded:**
`motoko-ext-compose`'s eight clock reads are unrouted and sit outside `driver_only`'s reachable set
**only because `driver_only` installs nothing.** This row's pass is real for this profile and buys
nothing for the next one.

### 6 — production logic is under test. PASS

The runner calls the real traced session driver with threaded world state; no test transition loop
computes state-machine decisions or history. `terminal_trace_dst PASS` with `✓ all terminal returns
route through c2_finalize`, enforced structurally by counting terminal record literals in
`session.ail`. `smoke_driver: 0 failed` across its scripts plus `✓ src/core/test/scripted_ports.ail
(6 unit tests)`. `capability bypass remains a non-zero run (D6.6)`.

### 7 — the oracle is complete. **PASS, ON A READING I AM REPORTING RATHER THAN TAKING SILENTLY**

Two conjuncts hold outright.

- **Exactly one final `RunSummary` per terminal path.** `terminal-summary` family green, with
  `✓ mutant: a RunSummary on a harness failure → summary-on-harness-failure` proving it
  discriminates, and `✓ mutant: a harness failure → harness-failure-observed`.
- **All D7 invariants pass.** `invariants_dst PASS`, `✓ the fixture satisfies all twelve families`,
  `✓ all 12 families reached`, `✓ 12 InvariantFamily variants == 12 in all_families(); all 37
  Violation constructors sampled by name`, `✓ first_failed_invariant is None on a clean run`.

**The third conjunct — "all logical ledger emissions appear in the returned trace" — is where the
reading lives.** Measured this run:

```
✓ every variant classified: 28 logical, 6 display-only
i 2 logical variant(s) do NOT reach the returned trace today — D6.4's gap:
      gap: ScratchpadResult, SessionSuspend
✓ the register agrees with the vocabulary in both directions
```

**Twenty-six of twenty-eight Logical variants reach the returned trace. Two do not.** On the
unqualified reading of the row's text, that is false and the row is RED.

**WI-D2 closed this row on a stated reading: *emissions that OCCUR reach the trace*.** Both survivors
are **coverage** gaps rather than parity gaps — no run in this tree emits them at all, measured
rather than argued, and their emission sites are inside the log the driver appends, so if one did
occur it would reach the trace. The positive half of the claim is checked out of process, per
variant, by comparing what the driver **projected** against what it **appended**:

```
=== ledger_parity wire-vs-trace (D6.4, general) ===
  ✓ CostExhausted: projected 1, returned 1        ✓ NativeToolCalls: projected 6, returned 6
  ✓ DelegatedToolDeferred: projected 1, returned 1 ✓ NativeToolDenied: projected 3, returned 3
  ✓ DoneEvent: projected 5, returned 5            ✓ NativeToolResults: projected 6, returned 6
  ✓ Dp7VerifierRejected: projected 4, returned 4  ✓ ThinkingStreamEnd: projected 16, returned 16
  ✓ ExtToolHandled: projected 1, returned 1       ✓ ToolPending: projected 1, returned 1
  … 17 variants, every one equal
  ✓ the fixture witnesses at least 17 required variants on both channels
ledger_parity wire gate PASS
```

and D6.4's named stream exception remains discharged separately: `stream_parity wire gate PASS`,
`wire_deltas=14 trace_deltas=14 subjects=2`, out of process so the recorder does not grade itself.

**Why this is not the narrowing C4 forbade.** C4's handoff named two illegitimate one-line escapes:
reclassifying Logical variants as `DisplayOnly`, and narrowing `driver_only`'s declared reach until
the gaps fall outside it. **D2 did neither** — the pinned `DisplayOnly` baseline is still the same
six, a row asserts by name that all eleven variants D2 closed are still classified Logical, and
`driver_only`'s coverage claim is unchanged. D2 closed the row by **appending eleven variants to the
trace**, which is doing the work rather than redefining it.

**But the reading is still a reading, and here is what a reviewer should weigh.** At C4 the row
failed *under every reading* — eleven of the thirteen registered variants were `driver_only`-
reachable, so no profile-scoped reading could rescue it, and C4 said so explicitly. **D2's work
removed exactly those eleven, leaving the two that no reading was ever going to reach.** The reading
therefore became load-bearing at the moment it stopped being decisive. That is worth stating plainly:
**the row's pass depends on "logical ledger emissions" meaning emissions the axis can produce, rather
than every Logical variant in the vocabulary.**

**And one of the two exemptions is bought by the empty install list.** `ScratchpadResult` is
reachable by a hook returning `Handled` with a `cells` key — **so no run emits it because nothing is
installed**, which is the same purchase as row 3's vacuity and row 4's `extension_effect_fault`
waiver. `SessionSuspend` is different: it needs a suspend trigger no profile has, and is not about
extensions.

### 8 — harness failures are separate. PASS

`✓ rich: a mismatch returns a typed HarnessFailure with position and projection` and the same for
`maxsteps`; `✓ dispatch reaching an EXCLUDED hook returns a typed HarnessFailure
(routing_violation)`; `✓ mutant: a RunSummary on a harness failure → summary-on-harness-failure`
proves no synthetic production summary is fabricated. Raw capability-bypass poison probes fail the
run non-zero and are kept distinct from the typed class, which is D6.6 in force.

### 9 — discovery and replay are stable. PASS

`discovery_dst PASS`, `strict_replay_dst PASS`. The censuses are identical member for member across
the discovery/replay boundary:

```
CENSUS rich        expect_provider=9 expect_tool=4 expect_approval=8 environment_read=14 advance_clock=7
CENSUS rich_replay expect_provider=9 expect_tool=4 expect_approval=8 environment_read=14 advance_clock=7
CENSUS pairA       expect_provider=4 expect_tool=1 expect_approval=3 environment_read=11 advance_clock=4
CENSUS pairA_replay expect_provider=4 expect_tool=1 expect_approval=3 environment_read=11 advance_clock=4
```

Replay runs under the recorded manifest without invoking the generator, and the wire witness is
compared out of process. `program_persistence_dst PASS`; in `corpus_pr`, every member's retained
bytes load back to the same identity and **the manifest travels inside the artifact**.

### 10 — hermeticity is enforced. **PASS**

The row names four bypass classes. **Five two-sided poison pairs answer them, and C4's red clause is
the one D3 closed:**

```
✓ deterministic world completes with AI withheld     ✓ live world dies with AI withheld
✓ deterministic world completes with Clock withheld  ✓ live world dies with Clock withheld
✓ deterministic world completes with Env withheld    ✓ live world dies with Env withheld
✓ deterministic world completes with FS withheld     ✓ live world dies with FS withheld
✓ fully-seeded world completes with Process withheld ✓ unseeded tool world dies with Process withheld
```

Each pair's second half is what stops the first from being vacuous. RNG is honestly reported as
unused rather than claimed: `✓ no driver module (src/core/*.ail) reaches std/rand`, checked
structurally. The env class **also** keeps its provenance assertion, which the gate prints as *"a
different claim, not a replacement"* — C4 ruled provenance is not hermeticity, and that ruling stands;
the pair is what carries the row.

**The filesystem pair is a fifth class beyond the four the row enumerates**, and it exists because
the host-env clause could not be closed without it: routing `resolve_context_limit`'s `Env` half
alone would hand back a world-supplied path to an ambient file.

### 11 — there is actual search. **PASS**

The failing clause at C4 was *"the fixed bank reaches every required non-waived fault class"*. It now
does — nine of nine, above. Everything else the row asks holds, read from the artifact:

```
✓ declared: dst-pr-corpus: minimum 12 seed(s), budget 5000 ms (13 affordable at 381 ms/seed)
✓ the bank's SEED count meets the declared minimum (15 ≥ 12)
✓ the minimum fits the budget at the measured 381 ms/seed (13 affordable)
✓ all 16 artifact identities are distinct       ✓ all 16 trajectory keys are distinct
✓ the bank carries all 3 member kinds: fixed-seed, promoted-regression, constructed-for-class
✓ mutant: fewer seeds than the declared minimum → window-below-minimum
✓ mutant: a promoted regression naming no failure → promoted-without-failure
✓ mutant: the run outlived its declared budget → corpus-budget-exceeded
```

Class-reached and branch-reached are reported as separate counters. Counterexamples are retained with
their manifests, including `seed-141`, a promoted regression carrying five fault classes in one
Err-terminating run.

**The cost margin is thin and the gate says so.** 5000/381 = **13 affordable against a declared
minimum of 12** — it fits by one seed, where at C4's 292 ms/seed it fit by five. D4 set that
constant from a measurement of a generator that is no longer truncated. **The next rise puts the
affordable count below the minimum**, and the honest response then is to raise the budget or lower
the minimum, not to re-measure until the number is convenient.

## THE NAME DECISION

**The label is ADOPTED for the generated axis. `driver_only/10` is the documented baseline profile
that earns it.**

**D10's text is not ambiguous and this decision does not turn on a contested reading of it:**

> The unqualified "DST"/"simulation" label is adopted for the generated axis only after the
> acceptance test below passes **for a documented baseline profile** and the project-007
> definition/taxonomy ADR is accepted. Every report names the profile; **additional profiles earn
> coverage separately.**

Both conditions are met. `driver_only` is documented, is the baseline, and its table is green at
eleven of eleven. The ADR was accepted 2026-07-26. **And the clause that would otherwise be the
objection — that this baseline covers no extension — is the clause D10 already anticipates:
"additional profiles earn coverage separately" says in as many words that one profile's green table
does not carry another's coverage.** Declining on that ground would be substituting a judgement for
the rule the ADR states.

**What the label now asserts:** that the generated axis, *for this profile*, generates executions
from seeds rather than values; models provider, tool, approval, clock, environment and filesystem in
one state-threaded world; injects logical faults that reach nine named production recovery branches;
routes every profile-reachable time-bearing read through the world clock; runs the real driver;
returns a trace complete over every emission the axis produces; separates harness failures from
production outcomes; replays exactly under a recorded manifest; enforces hermeticity with five
two-sided poison pairs; and searches with a bounded corpus that meets an operator-accepted minimum.

**What the label does NOT assert, and this sentence is mandatory in every report:**

> **The axis's extension-model coverage is ZERO, and that is structural rather than incidental.**
> `driver_only` installs no extension, and B4 proved the empty install list is **forced**: no
> extension in the tree is installable in a conformant profile while `ExtensionHooks.on_budget_plan`
> declares the ABI's closed row `! {Env, FS}` and returns a `BudgetPatch` with no successor field —
> criterion 1 fails on the declared row, criterion 2 fails for want of returned world state, and no
> binding by any extension can do better. **Nothing about the extension model has been tested by this
> gate, and nothing in this verdict says otherwise.**

**UPDATED BY WI-D6 ON 2026-08-06 — one clause is now false, and the claim the sentence exists to make
is not.** The paragraph above is left exactly as D5 wrote it, per S15; this is the amendment beneath
it rather than an edit inside it.

**FALSE FROM 2026-08-06:** *"that is structural rather than incidental"*, and the whole `forced`
clause. WI-D6 narrowed `on_budget_plan`'s ABI row to none after measuring all fifteen bindings in
the tree against two producers independent of the declaration — the runtime capability trap out of
process (7 of 15 directly witnessed) and the effect checker over all 15, total over inputs. **Not
one performs `Env` or `FS`.** An extension is installable in a conformant profile.

**STILL TRUE, STILL MANDATORY IN EVERY REPORT:** *"the axis's extension-model coverage is ZERO …
nothing about the extension model has been tested by this gate."* `driver_only` installs no
extension. **The emptiness moved from FORCED to CHOSEN, which is a weaker claim than D5's, not a
stronger one** — a chosen emptiness covers exactly as much as a forced one.

**And per S21, applied to the four rows in the table below, which is the rule's first deliberate
use.** None of the four closed. Each one's REASON concentrated:

| Row | Before WI-D6 | After WI-D6 |
|---|---|---|
| 3 | Vacuous, on an install list that **no profile could fill** | Vacuous, on an install list **this profile chooses not to fill** |
| 4 | `extension_effect_fault` waived by construction — doubly secured, by the empty list AND by the ABI | Waived by construction — the waiver text never named the ABI, so it is **unchanged in words**; it now rests on one reason where it rested on two |
| 5 | Compose's eight unrouted clock reads outside reach because nothing is installed | Unchanged, and now **actionable**: compose is installable, so the next profile must route them or declare them |
| 7 | `ScratchpadResult` unreachable because no hook is installed to emit it | Unchanged. It needs a hook returning `Handled` with a `cells` key, and a profile that installs one |

**The count is still four.** WI-D6 removed a barrier, not a vacuity — and the distinction is exactly
what S21 was written to make visible. A reader who takes "extensions are now installable" as movement
on any of these four rows has made the error D5's mandatory sentence exists to prevent.

**Four of the eleven rows lean on that emptiness in a named clause — two more than the handoff
carried forward, and finding the fourth is this item's analytic result:**

| Row | What the empty install list buys |
|---|---|
| 3 | **The pass is vacuous.** Every clause quantifying over installed extensions ranges over the empty set |
| 4 | The `extension_effect_fault` **waiver** — waived "by construction (plan P4)" |
| 5 | **Transferability.** Compose's eight unrouted clock reads are outside reach only because nothing is installed |
| 7 | The `ScratchpadResult` **exemption** — no run emits it because no hook is installed to emit it |

**Row 7 is the new one, and it appeared precisely because D2 succeeded.** At C4 the register held
thirteen variants of which eleven were `driver_only`-reachable, so the profile's emptiness bought
nothing there. D2 closed those eleven, and what remains is a residue in which one of two entries is
purchased by the empty install list. **Closing a row can concentrate a vacuity rather than remove
it**, and nothing in this project's rules would have caught that — it is only visible by asking, of
each surviving exemption, *why* it survives.

**Per D10, none of the four transfers.** A second profile earns rows 3, 4, 5 and 7 again from
scratch, and for row 3 it earns them non-vacuously or not at all.

## What adoption changes, and what it does not

**It is not a rename, and there is no cascade waiting.** 007's ADR grandfathers every existing `dst`
identifier — the `dst` and `dst_seeded` targets, module and script names, PASS labels, workflow text,
the as-built title — and states that the exception *"prevents churn; it does not confer the new
meaning."* Every target project 009 added already uses a non-simulation working name
(`attribution_table`, `corpus_pr`, `driver_only`, `ledger_parity`, `stream_parity`, `world_state`,
`seeded_generator`, `declared_vs_performed`, `hook_guard`). **D10's adoption permits the label; it
requires renaming nothing, and nothing was renamed.**

**The public record is one document**, and it is updated in this item:
`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`. Three claims are superseded, and
**per S15 each is restated with its date rather than deleted** — they were true when written, and a
bare number or tense silently re-dated inside a historical record becomes a false claim about
history:

| Site | Superseded claim |
|---|---|
| `:8` | what is built *"does not yet meet that ADR's conformance bar"* |
| `:46-47` | the axis is *"strictly stronger than trace replay, strictly weaker than DST"*, with an *"interim name"* |
| `:292` | the deterministic test world *"would earn the DST name"*, listed as **known deferred work** — and blocked on an upstream API that landed at B1 |

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243 files.**
  Run first, per S13. **The failing set matches the expected seventeen member for member:** 7
  `TC_ARITY_001` smoke scripts (`smoke_v2_conversation`, `factual`, `intercept`, `policy`,
  `tool_build`, `tool_read`, `tool_write`), the sealed-vocabulary probe
  (`probe_phase_vocab_sealed`), 5 `src/examples/` (`banking_system`, `csp_demo/main`,
  `recursive_stats`, `task_processor`, `test_match`), 3 code-graph fixtures
  (`sample3/agent_loop_v2`, `sample3/ok_effect`, `source_index/chunk_boundaries`) and 1
  test-coverage fixture (`unrunnable`). Stable across B4, C1, C3, C5, C4, D3, D4 and now D5.
- **`make dst` — EXIT 2, red set `test_coverage` and `test_coverage_selftest`, and nothing else.**
  Both pre-existing since B2a, attributed there to module resolution in `ailang test`; the selftest
  fails on `Named test blocks not yet implemented [stale_skip_record]` and `named_only.ail: also
  fired ['failing']`. **845 ✓ rows**, identical to D4's 845 — the same methodology, so the
  comparison is legitimate.
- **Every other target green**, including all eleven rows' producers: `world_state`,
  `profile_coverage`, `profile_definition`, `driver_only`, `fault_catalogue`, `event_vocabulary`,
  `invariants`, `run_report`, `latency_pair`, `corpus_pr`, `corpus_rotating`, `attribution_table`,
  `execution_program`, `discovery`, `strict_replay`, `seeded_generator`, `program_persistence`,
  `predicate_anchors`, `recorded_stream`, `stream_parity`, `ledger_parity`, `declared_vs_performed`
  (10 passed, 0 failed), `hook_guard` (4 passed, 0 failed), `smoke_driver`, `smoke_parity`.

## Recorded bindings: decided versus discovered

**Discovered — a tool or a measurement forced it:**

1. **Row 7's `ScratchpadResult` exemption is purchased by the empty install list**, so the
   extension-emptiness surface is **four rows, not two**. Found by asking of each surviving exemption
   why it survives, rather than by any gate.
2. **Closing a row can concentrate a vacuity rather than remove it.** At C4 the register's thirteen
   entries made the profile's emptiness irrelevant to row 7; at HEAD the two survivors make it
   load-bearing. The proportion of the row bought by emptiness went **up** as the row got better.
3. **Row 7's pass depends on a reading**, and that reading became load-bearing at the moment it
   stopped being decisive — C4 recorded that the row failed under every reading, which is exactly why
   nobody had to adjudicate it then.
4. **C4's two disagreeing `run_report` windows now agree** at 9 of 11 / 9 of 11. The measured window
   moved up to the fixture window rather than the reverse.
5. **`make dst` reproduces D4's 845 ✓ rows exactly**, and the sweep reproduces 226/17 member for
   member — so nothing regressed between D4's run and this one, on an unchanged tree.
6. **The PR corpus fits its budget by one seed** (13 affordable against a minimum of 12), where at
   C4 it fit by five. A consequence of D4's honest re-measurement, not of any change here.
7. **The as-built document's deferred-work entry is stale in a second way** nobody has recorded: it
   says the work is *"currently blocked on an upstream AILANG recorded-stream API"*, which landed at
   B1 and was adopted at C1/C2.

**Decided — a human chose:**

1. **The name is ADOPTED**, on D10's plain text, with the zero-extension-coverage caveat made
   mandatory rather than optional.
2. **Row 7 passes, and the reading it passes on is reported in the verdict** rather than absorbed —
   so a reviewer who rejects the reading knows exactly which row to reopen and what the answer would
   become.
3. **Row 2 passes unqualified**, because C4's qualification was booked against row 10 and row 10 is
   closed.
4. **Rows 3 and 5 are marked as C4 and D3 marked them**, but distinguished from each other: row 3's
   *pass* is vacuous, while row 5's pass is real and only its *transfer* is not.
5. **The four leaning rows are tabulated together**, because the individually-recorded caveats had
   never been counted and the count is the thing that makes "coverage is zero" concrete.
6. **The as-built document is updated with dated supersessions rather than deletions** (S15), and the
   third site's stale upstream-blocker clause is corrected in the same pass.
7. **Nothing was renamed.** Adoption permits the label; it does not require churn, and 007
   grandfathers the existing identifiers explicitly.

## Sites where two answers type-checked and one was silently wrong

**None. The counter stays at 55.**

**This item wrote no production code** — it ran two gates, read their artifacts, and edited one
design document. There was no site at which two answers could type-check.

**Determinism has still caught none of the fifty-five**, and per S20 this item is a case where
determinism would have been *actively reassuring about the wrong thing*: every figure in this
verdict is reproducible, and reproducibility is exactly what D4 proved can hold while the property it
appears to confirm is false. **The reason this run's numbers are trustworthy is not that they
reproduce D4's — it is that the salts no longer count driver interactions, so the quantity being
reproduced is now a function of the seed.** A run that reproduced D4's numbers *before* S20 would
have proved nothing at all.

## Corrections owed to the plan

1. **THE PLAN HAS NO ITEM FOR THIS WORK, AND NOW HAS NO ITEM AT ALL.** C4's planning defect 1 —
   *"the plan still has no item after Milestone C"* — stands unchanged through D1, D2, D3, D4 and
   this item. The last work item in the plan is **WI-C5** (the `compose`-bearing second profile),
   which is unbuilt. **Five consecutive items have executed with no plan entry**, and this one closed
   the project's headline milestone that way. The plan should record D5 and the adoption.
2. **THE PLAN'S WI-C4 ENTRY STILL DOES NOT SAY WHAT A YES MEANS.** C4's planning defect 3 asked for
   the NO branch and it was added. **The YES branch is still absent** — nothing in the plan says that
   adoption is a documentation act with a mandatory caveat rather than a rename, which is why that
   had to arrive by handoff.
3. **A VACUITY CAN MIGRATE BETWEEN ROWS WHEN A ROW CLOSES, AND NOTHING TRACKS IT.** The project has
   carefully tracked *which* rows pass vacuously since C4, and the count moved from two to four
   without any item noticing, because each individual caveat was recorded correctly in its own row's
   prose. **Suggested rule: when a row closes, re-ask of every surviving exemption in every other row
   why it survives — a closure narrows the set of reasons, and a reason that used to be one of many
   can become the only one.**
4. **"WHAT THE LABEL DOES NOT ASSERT" NEEDS TO BE A CHECKED ARTIFACT, NOT PROSE.** The
   zero-extension-coverage sentence is now load-bearing for every future report, and today it is a
   paragraph in a note and a paragraph in a design document — **exactly the class S15 says gets
   quoted forward and re-dated.** The gate already computes everything it asserts (empty install
   list, forced by the ABI row, guarded by `make driver_only`). A row that prints the caveat as
   output would make it impossible to report a green table without it.
5. **S19's artifact rule earned itself again, quietly.** Rows 4 and 11 were read from
   `/tmp/corpus_pr.out` and the class rows were present and green. Had they been red, the transcript
   would again have shown a 40-line tail they scroll off. **The rule works; the recipe is still the
   shape that made it necessary.**

## Out of scope, unchanged and still owed

- **The `on_budget_plan` ABI change** — the one item that would make the two vacuous passes
  non-vacuous, and the only substantive work left. A second ABI major with a profile bump behind it.
  **DONE AT WI-D6 (2026-08-06), and it made no pass non-vacuous** — see the closing section. The
  profile bump happened (`driver_only/10` → `/11`); the ABI major is still owed and now covers five
  changed rows.
- **A second profile** (WI-C5, `compose`-bearing). None exists; additional profiles earn coverage
  separately.
- **The two sibling `st.world_state` finalize sites**, still ignoring `chain.next_state`; file reads
  in the interaction log; `FS` in `driver_only.forbidden_capabilities`; D4's provider latency pair;
  the adversarial partial stream; the `motoko-ext-abi` major; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.
- **`test_coverage` and `test_coverage_selftest`**, red since B2a and untouched here.

## The one item that would make the name transfer

**Widening `ExtensionHooks.on_budget_plan`.** Its closed ABI row `! {Env, FS}` and its
successor-free `BudgetPatch` return are jointly sufficient to make every extension in the tree
un-installable in a conformant profile. Until that changes, **no profile can install anything, so no
profile can earn rows 3, 4, 5 and 7 non-vacuously**, and the label — correctly adopted for the axis
— will keep resting on a baseline that covers no extension.

**Twelve items declined this name. The thirteenth adopts it, for one profile, on a green table of
eleven rows, and says in the same breath what that profile does not cover.**

---

**DONE AT WI-D6, 2026-08-06 — AND THE NAME DID NOT TRANSFER.** The section above is kept as written.
D6 did the item it names: `ExtensionHooks.on_budget_plan`'s row was narrowed to none, and every
extension in the tree is now installable in a conformant profile.

**What the section got right:** the row was the barrier, and one item removed it.

**What it got wrong, and it is worth stating because the same slip is available to the next reader:**
the section says removing the barrier is *"the one item that would make the name transfer"* and that
until it changes *"no profile can install anything, so no profile can earn rows 3, 4, 5 and 7
non-vacuously."* The second clause is true; **the first does not follow from it.** Removing the
barrier is NECESSARY for those rows and nowhere near SUFFICIENT — the rows are earned by a profile
that installs something and passes the table, and `driver_only` still installs nothing. **Nothing
transferred. The four rows lean exactly as far as they did.** What D6 bought is that WI-C5's
`compose`-bearing profile is now buildable at all, which is a precondition rather than a result.
