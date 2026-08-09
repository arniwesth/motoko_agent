# WI-D28 — the final acceptance rerun. **THE CLOSING NOTE.**

**VERDICT: YES. THE NAME STANDS, AND IT NOW RESTS ON A DEMONSTRATION RATHER THAN ON AN ABSENCE OF
COUNTEREXAMPLES.** Both goal-line clauses hold at HEAD. The eleven rows are green for three
profiles' worth of evidence, the vacuity register is a computed number for the first time, and all
fifteen extensions are mediated or disclosed with a measured reason.

Fifty-second calibration run. Written against HEAD `b3953a9`, branch
`arniwesth/mot-90-wi-d28-the-final-acceptance-rerun-the-closing-note`.

---

## 0. WINDOW AND GROUNDING

**~30 minutes** wall-clock: first measurement `2026-08-09T17:33Z`, last `2026-08-09T18:01Z`. One
measurement dominates it: `make dst` in full, `17:35:10Z` → `17:50:37Z` (**15m27s**). The upstream
filing was queued at `17:53:32Z`.

**`git status` clean at `b3953a9`** when this item started and when its measurements finished.
Nothing was resolved silently because nothing needed resolving. **This item's only tracked-file
output is this note**, and the scratch `repro.ail` written for §5 was deleted after measurement.

**S9's concurrency check, at the time of the measurements: no other session was running a gate.**
One live `ailang` process in this tree — a `src/core/supervisor.ail` agent run, 7h56m elapsed
against 1m43s CPU, holding no `.ailang/cache` or `/tmp/*.out` descriptors. Three defunct. An idle
agent session, not a gate.

**S9 AGAIN, AFTER THE FACT, AND IT IS WORTH RECORDING RATHER THAN QUIETLY BEING TRUE.** At
`18:08:59Z` — 18 minutes after this item's sweep finished and 4 minutes after this note was first
written — a **concurrent reviewing session** modified
`PLAN-implementation-deterministic-test-world.md` with the WI-D28 apply entry, and started its own
`make dst`. **No measurement in this note was taken after `18:01Z`**, so none of them overlapped a
second gate run; the sequence was checked against file mtimes rather than assumed. The reason this
paragraph exists is D4: *"a concurrent `make dst` and every measurement would have been poisoned
silently"* — the check is worth running at the end as well as the beginning, and this is the first
item where it would have mattered.

**Caches, and this run is NOT cache-cold in D5's sense — stating it rather than implying it.**
Four live `.ailang/cache` directories were cleared before the sweep (`examples/`, `scratchpad/`,
`scripts/`, `tmp/` — the set `ls -d */.ailang/cache` matches); `~/.ailang/cache/registry` was left
alone and verified intact. **`find . -type d -name cache -path '*/.ailang/*'` reports 48 in the
tree**, including one per extension package and the `.packages/motoko_core` mirrors, and those were
**not** cleared. So the sweep ran warm with respect to the package caches. D5 cleared eight and
called its sweep cache-cold; this one cleared four and does not. Nothing below turns on the
difference — a warm cache cannot turn a red row green — but the methodology differs from D5's and
a comparison of run times would be reading two different measurements.

**The one producer that depends on cache contents establishes its own precondition and says so:**
`derive.py` runs with `do_provision=True` and reports `"provision_failures": []`, `18/18 std modules
resolved`, `0 unresolved symbols` — it built what it needed rather than trusting what it found.

Per S19, `/tmp/corpus_pr.out`, `/tmp/latency_pair.out`, `/tmp/corpus_rot.out` and
`/tmp/corpus_job.out` were **deleted before the run**, so every artifact read below was written by
this item's own `make dst` (all four re-appear stamped `17:38–17:39`).

**The producer's own revision check agrees.** `derive.py --json` reports
`"source_revision": "b3953a962c2ef6dc835896cad374de55fbf211fc"` and
`"compiler": "AILANG v0.33.0"` — the classification table below is derived at the same revision
this note is written against, by the tool's own statement rather than mine.

**Nothing in this item was fixed.** Six findings are reported below and every one goes to the
maintenance register. No gate was weakened, no row re-argued, no register item closed. The only
non-scratch artifact this session produced outside this note is the upstream filing (§5).

---

## 1. THE ELEVEN ANSWERS, RE-RUN

The table is `ADR-001` §"Acceptance test for the name" (`ADR:2533`). Every row's producers were
re-derived from D5's own "Produced by" column and run at HEAD in this session.

**Eleven of eleven hold. No row is red.** One row still passes on a stated reading and it is the
same reading D2 stated and D5 reported — see row 7.

| # | Row | Verdict | Delta since D5 | Produced by |
|---|---|---|---|---|
| 1 | one seed generates an execution | **PASS** | one pair digest moved; the control's property is unchanged | `discovery` · `strict_replay` · `seeded_generator` · `execution_program` |
| 2 | a modeled logical environment | **PASS** | unchanged | `world_state` · A12 probe |
| 3 | the tested boundary is honest | **PASS — and transformed** | three profiles; first non-empty `excluded`; per-extension ids non-vacuous; floor, exclusion rule and disclosure all exercised (D14/D27) | `driver_only` v22 · `driver_plus_no_ops` v9 · `driver_plus_compose` v1 · `profile_coverage` · `profile_definition` · `hook_guard` |
| 4 | faults reach production recovery | **PASS** | identical numbers; the `extension_effect_fault` waiver's *ground* changed shape three times (D14/D27) | `corpus_pr` artifact · `fault_catalogue` · `run_report` |
| 5 | virtual time matters | **PASS — re-earned on ROUTING** | D5's pass rested on absence; compose's intercept now calls `clock_now` **through the world** (D19/D27) | `driver_*` routed-set claims · `world_state` Clock pair · `latency_pair` artifact |
| 6 | production logic is under test | **PASS — strongest instance in the tree** | a real traced session with an installed effectful extension (D27) | `smoke_driver` · `terminal_trace` · `world_state` · `driver_plus_compose` |
| 7 | the oracle is complete | **PASS on the same stated reading** | the `ScratchpadResult` exemption re-earned twice, on grounds that are not emptiness | `invariants` · `event_vocabulary` · `ledger_parity` · `stream_parity` |
| 8 | harness failures are separate | **PASS** | the exclusion arm now has a profile with a non-empty exclusion behind it | `strict_replay` · `world_state` poison pairs · `hook_guard` |
| 9 | discovery and replay are stable | **PASS — strongest instance in the tree** | a recorded, validated, strictly-replayed compose session (D27) | `discovery` · `strict_replay` · `program_persistence` |
| 10 | hermeticity is enforced | **PASS — per profile, and the compose profile's boundary is stated** | the compose profile GRANTS `Env`/`FS` across registration, disclosed bidirectionally (D27 §6) | `world_state` — five two-sided poison pairs |
| 11 | there is actual search | **PASS** | identical; the budget margin is unchanged and still thin | `corpus_pr` artifact · `corpus_rotating` |

### Row 1 — one seed generates an execution. PASS

`discovery_dst PASS`, `strict_replay_dst PASS`, `execution_program_dst PASS`,
`program_persistence_dst PASS`. Zero unexpected harness failures.

**The anti-count control is intact and its numbers moved, which is worth stating precisely.**
`seeded_generator` prints:

```
✓ different seeds produce different programs at EQUAL interaction count
  (n=23, digests 722021275 vs 1372950750)
```

D5 recorded `n=23`, digests `2144863192 vs 1372950750`. **One member's digest moved across the
D6→D27 wave and the other did not.** The control's property — equal count, different digest — is
unchanged, and that is what the row asks. A digest that moves when the generator changes is the
expected behaviour; the reportable fact is only that the note does not quote D5's number forward.

S20's rows are green and are what make the row mean what it says: `rich` made **111** generator
choices, `pairA`/`pairB` **47** each, `versioned` **11**; the bound is asserted `== budget + 1`;
`✓ ...and the counted quantity is a PROPER subset of the log — the filter counts and excludes`; and
`✓ the tightened bound (3) is BELOW this seed's natural trajectory (4)` against a measured
`seed 77 authors 4 generator interaction(s) at the declared bounds (log total 19)`. Axis J:
`✓ two generations at one seed produce byte-identical programs`.

### Row 2 — a modeled logical environment. PASS

The A12 probe's advancement rows are green — `advance: cursor advances`, `advance: served sequence
is exactly the script`, `advance: exactly one run_summary, and it is last`, `fold: served sequence
is exactly the script`, `exhaust: cursor advances to the budget`. Runtime randomness is honestly
reported as unused (`runtime_random_draw=0` on every census) and honestly witnessed where exercised
(`runtime_random_draw [runtime-witness] witnessed=6 logged=6`).

`world_state` now models a filesystem with a three-valued path class, and the census carries
`file_write`, `file_remove` and `dir_make` columns that were not in D5's vocabulary — the world got
wider, and the row's answer is unchanged.

### Row 3 — the tested boundary is honest. **PASS. THIS IS THE ROW D5 CALLED VACUOUS, AND IT IS THE ROW THAT CHANGED MOST.**

D5's answer was *"PASS — VACUOUS in every installed-extension clause"*, because `driver_only`
installed nothing. At HEAD there are **three profiles**, and the row's four installed-extension
clauses are exercised as follows. Every line below is quoted from the profiles' own output.

**Clause 1 — the coverage floor.** Non-vacuous in two profiles:

```
driver_plus_no_ops:  compaction_structural: 8 hook(s) covered — floor satisfied, non-vacuously
                     decision_framework: 8 …  empty_stop_guard: 8 …  progress_contract_guard: 8 …
driver_plus_compose: compose: 7 hook(s) covered, 1 excluded — floor satisfied, non-vacuously
```

**Clause 2 — no unconditionally-dispatched hook excluded.** `driver_plus_compose` is the first
profile with a non-empty `excluded` list at all: `on_tool_handle`, which is the one gated slot in
the ABI, re-derived from the dispatch table rather than asserted.

**Clause 2b — the exclusion is stated in two D5 fields and they agree.** Field 9
`disclosures.excluded = [on_tool_handle]` against `hook_classifications = ExplicitlyExcluded` on the
same id, basis `disclosure`.

**Clause 3 — no installed extension calls a classifier-2 `ExtPorts` field. STILL VACUOUS IN ALL
THREE PROFILES**, and this is a finding (§4.2). The derived classifier-2 call list is empty at HEAD,
so the rule passes over nothing:

```
CLAIM row3c classifier_2_calls_in_installed_closures=0     (driver_plus_compose)
CLAIM row3c ext_ports_calls_in_installed_closures=0        (driver_plus_no_ops)
! note: check 3 is now VACUOUS (zero classifier-2 member call sites).  (profile_definition)
```

**Clause 4 — per-extension covered/excluded hook IDS. Non-vacuous, with real ids.** Compose's are
printed in full (`covered: on_describe_tools, on_build_system_prompt, on_budget_plan, on_pre_step,
on_tool_policy, on_response_intercept, on_solver_candidate` / `excluded: on_tool_handle`), and the
same for four extensions under `driver_plus_no_ops`.

**The rejecting fixtures still bind unconditionally.** `profile_coverage_dst PASS` — three profiles
that must load (including `driver_only`'s empty install list and a gated-hook exclusion) and six
that must be rejected, each **by its own rule**: `[coverage-floor]`,
`[unconditional-hook-excluded]`, `[covered-excluded-exhaustive]`, `[covered-excluded-disjoint]`,
`[duplicate-extension-id]`, `[unknown-hook-id]`, plus `✓ two defects: both rules named` and
`✓ ids: equal counts (3), distinguishable ids`.

**What is still exercised only by fixture:** *"dispatch to an exclusion fails closed."*
`hook_guard: 4 passed, 0 failed`, and `driver_plus_compose` asserts the check both ways
(`dispatching on_tool_handle under this profile IS a routing violation; dispatching
on_response_intercept is NOT`) — but **the graded session dispatches no tool at all**, so no run in
this tree reaches an excluded dispatch. D5 recorded this as *"the mechanism is demonstrated; it is
not exercised by the baseline"*; at HEAD it is not exercised by any of the three.

### Row 4 — injected faults reach production recovery code. **PASS**

Read from `/tmp/corpus_pr.out`, per S19, not from the transcript:

```
✓ the corpus validates against 9 expected class(es): provider_error_retryable,
    provider_error_non_retryable, provider_protocol_inconsistent_result,
    provider_partial_stream_then_error, provider_empty_terminal_response,
    ToolFailed, ToolCorrelationMismatch, ToolDeadlineExceeded, approval_denied
✓ the unreachable register is EMPTY: every required non-waived class is reached
    by SEARCH, none subtracted
✓ every expected class was OBSERVED (declared ⊆ observed)
✓ every observed class is EXPECTED (observed ⊆ declared)
```

The wire answers *recovery code* independently, and reproduces D5's counts exactly:

```
✓ wire witness, branch-reached: approval_denied×35 empty_stop_finalize×1 ToolFailed×3
  ToolCorrelationMismatch×4 ToolDeadlineExceeded×5 stream_error_retry×5
  provider_failure_finalize×13 malformed_arguments×7
  (against 65 executed dispatch batch(es), so neither side of the approval decision is unwalked)
```

`run_report` agrees: `✓ fault classes reached: 9 of 11` and `✓ NAMED recovery branches reached:
9 of 11`, both counters, both windows, and `✓ the 2 surviving gaps carry 2 DISTINCT reasons`.
Nine of nine is still **eight by search and one by construction** — `constructed-empty-terminal`
carries its own measured reason (`0 of 260 swept seeds, and 0 empty_stop_finalize records on the
wire across the whole sweep`).

**The `extension_effect_fault` waiver, per profile, honestly.** The catalogue's condition text is
one string and three profiles now record it:

```
fault_catalogue: extension_effect_fault: the selected D5 profile installs an extension with an
  effectful hook that issues this world request; driver_only installs none, so it waives this
  class by construction (plan P4)
```

- **`driver_only` v22** — waived **by construction**. The condition text is about this profile and
  is true of it. D5's ground, unchanged.
- **`driver_plus_no_ops` v9** — waived, **and not by emptiness**: four extensions are installed and
  `CLAIM row4 ext_ports_calls_in_installed_closures=0` re-derives that classifier 3 finds zero
  `ExtPorts` field calls in any installed closure, so no installed hook can issue the request.
  *Inapplicable, measured.*
- **`driver_plus_compose` v1** — waived, **and this profile installs an extension WITH an effectful
  hook**. The ground is a per-FIELD fact: `CLAIM row4 ai_step_calls_in_installed_closures=0` — the
  class is delivered by `ExtPorts.ai_step`, compose's only path to a provider is the ambient
  `callStreamResult`, and that path is behind the EXCLUDED `on_tool_handle`. The profile records
  that *"the waiver would fail the moment this profile covered that slot or installed
  compaction_ai."*

**FINDING, and the fourth consecutive artefact to record it:** the catalogue's condition names
`driver_only` verbatim and the machinery requires an exact match, so **two of the three profiles
record a sentence about a different profile.** Reported, not fixed — it is a catalogue content
change and it is on the register.

The other waived class (`approval_deadline_exceeded`) rests on a genuine production-policy
condition and is unrelated to any install list.

### Row 5 — virtual time matters. **PASS, AND RE-EARNED ON ROUTING RATHER THAN ON ABSENCE**

The routed-set claim is **computed, not recorded**, and is identical in all three profiles:

```
✓ routed-set claim, COMPUTED at the bound revision (nothing recorded):
      reachable core sites: 7   routed: 6   declared unrouted: 1
```

The one unrouted site is `src/core/test/stub_step.ail:203`, the live adapter, **declared and
instrumented** — its instrument is the Clock poison pair, which shows the deterministic entry point
completing with `Clock` withheld and the live world dying.

**The delta is the whole of this row's movement.** D5's pass was real and non-transferable, and its
caveat was that compose's eight unrouted clock reads sat outside `driver_only`'s reachable set
*only because nothing was installed*. `driver_plus_no_ops` re-earned it on measured absence
(`CLAIM row5 ambient_sources_in_installed_closures=0` — no installed extension reads a clock at
all). **`driver_plus_compose` is the first profile whose install set reads a clock**, and it earns
the row on routing instead:

```
AND THIS IS THE FIRST PROFILE WHOSE INSTALL SET READS A CLOCK AT ALL. compose's
intercept calls clock_now — through ExtPorts, which is routed; WI-D26 §13.1
measured 0 ambient Clock sources in any compose hook path.
CLAIM row5 ambient_clock_sources_in_installed_hook_paths=0
```

The latency pair holds, read from `/tmp/latency_pair.out`: `latency_pair_dst PASS`,
`✓ the provider script, the approval queue and the declared deadline are identical`,
`✓ both runs made the SAME tool request (identity and projection identical)`, both halves replay to
identical interaction logs, and `✓ wire witness: 4 of 9 native_tool_results carry
ToolDeadlineExceeded (the slow halves, and only those)`. No OS timeout is invoked.

### Row 6 — production logic is under test. **PASS, and the tree now holds its strongest instance**

`terminal_trace_dst PASS` with `✓ all terminal returns route through c2_finalize`, enforced
structurally; `smoke_driver: 0 failed` across eight scripts plus
`✓ src/core/test/scripted_ports.ail (6 unit tests)`; `✓ capability bypass remains a non-zero run
(D6.6)`.

**What is new since D5 is the subject, not the row.** `driver_plus_compose` runs a full graded
session through the real traced driver with compose installed via its own `register_with_config`:

```
✓ the graded session reached its terminator
    census: expect_provider=2 expect_tool=0 expect_approval=0 expect_extension_effect=1
            environment_read=10 runtime_random_draw=0 advance_clock=4
            file_write=1 file_remove=1 dir_make=1
✓ compose's routed seam RAN — the extension reached the recorder
✓ compose took the FAILURE branch, on the typed exit code and not on the rendered one
✓ the served content reached the model: the diagnostic came back through the decode
```

D5's answer was about the driver. This one is about the driver **with an effectful extension inside
it**, and it is the first time the row has had that subject.

### Row 7 — the oracle is complete. **PASS, ON THE SAME READING D2 STATED AND D5 REPORTED**

Two conjuncts hold outright. `invariants_dst PASS`: `✓ the fixture satisfies all twelve families`,
`✓ all 12 families reached`, `✓ 12 InvariantFamily variants == 12 in all_families(); all 37
Violation constructors sampled by name`, `✓ first_failed_invariant is None on a clean run`, plus
`✓ mutant: a RunSummary on a harness failure → summary-on-harness-failure`.

The third conjunct is unchanged, measured this run:

```
✓ every variant classified: 28 logical, 6 display-only
i 2 logical variant(s) do NOT reach the returned trace today — D6.4's gap:
      gap: ScratchpadResult, SessionSuspend
✓ the register agrees with the vocabulary in both directions
```

The positive half is checked out of process, per variant — `ledger_parity wire gate PASS`, 17
variants each with `projected N, returned N` and every one equal (`ProviderCallPrepared: 16/16`,
`ProviderResult: 15/15`, `RunSummary: 8/8`, `ThinkingStreamStart`/`End: 16/16` …), plus
`stream_parity wire gate PASS`, `wire_deltas=14 trace_deltas=14 subjects=2`.

**The reading is the same and it is still load-bearing:** the row passes on *"logical ledger
emissions"* meaning emissions the axis can produce, not every `Logical` variant in the vocabulary.
If a reviewer rejects that reading, row 7 is red and this verdict is NO. That has been true since
D2 and nothing here changes it.

**What DID change is the ground under the `ScratchpadResult` exemption, and it changed twice.**
D5 recorded that no run emits it *because nothing is installed*. Now:

- **`driver_plus_no_ops`**: two independent facts, either alone sufficient —
  `CLAIM row7 provided_tools_empty_and_tool_handle_delegates`: all four installed extensions bind
  `provided_tools: []` (so the gated dispatch is never reached) **and** return `Delegate`, never
  `Handled`.
- **`driver_plus_compose`**: neither of those is available — compose's `provided_tools` is not
  empty and its `on_tool_handle` does not delegate. Two different facts carry it:
  `CLAIM row7 tool_handle_excluded_and_no_scratchpad_tool` — the slot is EXCLUDED in D5 field 9 (so
  a dispatch would be a routing violation), and compose provides no tool named `scratchpad`.

**The exemption survives in all three. Its ground has been replaced twice by measurements, and it
has never once been removed.** That distinction is the whole of S21 and it is why the register
below does not shrink.

### Row 8 — harness failures are separate. PASS

`✓ rich: a mismatch returns a typed HarnessFailure with position and projection` and the same for
`maxsteps`; `✓ dispatch reaching an EXCLUDED hook returns a typed HarnessFailure
(routing_violation)`; `✓ mutant: a RunSummary on a harness failure → summary-on-harness-failure`
and `✓ mutant: a harness failure → harness-failure-observed`. Raw capability-bypass poison probes
fail the run non-zero and stay distinct from the typed class (D6.6). `hook_guard: 4 passed,
0 failed`.

### Row 9 — discovery and replay are stable. **PASS, and the tree now holds its strongest instance**

`discovery_dst PASS`, `strict_replay_dst PASS`. The censuses are identical member for member across
the boundary:

```
CENSUS rich         expect_provider=9 expect_tool=4 expect_approval=8 environment_read=14 advance_clock=7
CENSUS rich_replay  expect_provider=9 expect_tool=4 expect_approval=8 environment_read=14 advance_clock=7
CENSUS pairA        expect_provider=4 expect_tool=1 expect_approval=3 environment_read=11 advance_clock=4
CENSUS pairA_replay expect_provider=4 expect_tool=1 expect_approval=3 environment_read=11 advance_clock=4
```

`✓ pairA: replay witness provider=4 tool=1 approval_reads=3 served=3 clock_delta=15ms` against
witnesses the recorder did not write, compared out of process. `program_persistence_dst PASS`; in
`corpus_pr`, every member's retained bytes load back to the same identity and **the manifest
travels inside the artifact** (`manifest: driver_only/22` on every member).

**And the compose session is the first replay of a run with an installed effectful extension:**

```
✓ the recorded program VALIDATES
✓ the reconstituted world's queues balance against the log — nothing unconsumed, nothing missing
✓ the reconstituted queue serves the same TYPED exit code the recording did
✓ the graded session REPLAYS to an identical interaction log
✓ NON-VACUITY, REPRODUCED: the replay records the same origin-tagged compose effect
✓ the REPLAY takes the same failure branch
```

### Row 10 — hermeticity is enforced. **PASS — PER PROFILE, AND THE COMPOSE PROFILE'S BOUNDARY IS PART OF THE ANSWER**

Five two-sided poison pairs, all green:

```
✓ deterministic world completes with AI withheld       ✓ live world dies with AI withheld
✓ deterministic world completes with Clock withheld    ✓ live world dies with Clock withheld
✓ deterministic world completes with Env withheld      ✓ live world dies with Env withheld
✓ deterministic world completes with FS withheld       ✓ live world dies with FS withheld
✓ fully-seeded world completes with Process withheld   ✓ unseeded tool world dies with Process withheld
✓ no driver module (src/core/*.ail) reaches std/rand
✓ every run above completed without the Rand capability ever being granted
```

**And here is the boundary statement the row's answer must carry from D27 §6, in the instrument's
own words rather than mine.** `driver_plus_compose` runs under
`--caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace`, and it says so:

```
-- REGISTRATION RUNS AMBIENT, AND THIS PROFILE'S RUNS GRANT {Env, FS} --
    compose's register_with_config reads getEnvOr("MOTOKO_PROFILE_DIR", ".") at
    register.ail:9, then fileExists/readFile at config.ail, BEFORE any hook is
    dispatched. AILANG capabilities are per PROCESS, so the withheld-capability
    poison discipline `make world_state` runs for the driver DOES NOT EXTEND across
    compose's registration. The gap is stated, not closed.
    WHAT CARRIES THE DETERMINISM CLAIM INSTEAD: the record → strict-replay identity
    asserted above. A registration read that varied with the host would make the two
    runs diverge, and the replay row would go red.
```

**So the honest form of row 10's answer at HEAD is: hermeticity is enforced PER PROFILE.** The
poison pairs are `driver_only`'s discipline and they are green. Under `driver_plus_compose` the
pairs say nothing about registration, and the determinism claim rides the replay identity — which
D27's mutant A showed going red when the subject is removed, so it is a load-bearing assertion
rather than a hopeful one. The three registration sources are disclosed in both directions against
classifier 3's own list (`✓ registration's 3 ambient source(s) disclosed, both directions`).

### Row 11 — there is actual search. **PASS**

Read from `/tmp/corpus_pr.out`:

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

plus eight further mutant rows, each named. `corpus_rotating` is green over six contiguous epochs
with `✓ consecutive epochs share NO seed`, `✓ the 4 shards partition the 240-seed window` and
`✓ the same epoch reproduces the same window`. Counterexamples are retained with their manifests,
including `seed-141`, five fault classes in one Err-terminating run.

**The cost margin is unchanged and still thin: 5000/381 = 13 affordable against a declared minimum
of 12.** It fits by one seed, exactly as at D5. The honest response to the next rise is still to
raise the budget or lower the minimum, not to re-measure until the number is convenient.

---

## 2. THE VACUITY REGISTER, COMPUTED

S21's obligation, finally as an output. **The register does not shrink to zero and was never meant
to** — the goal line renounced that explicitly. What follows is what it actually contains.

### 2.1 The fold, and the commands that produce it

**No permanent instrument was built** (§7 says why). This is a one-shot fold over lines the profiles
already print — all three are run, and two of the three have lines to fold (§4.4a):

```bash
ailang run --caps IO --entry main scripts/dst/driver_only_dst.ail          > driver_only.raw
ailang run --caps IO --entry main scripts/dst/driver_plus_no_ops_dst.ail   > driver_plus_no_ops.raw
ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
  --ai-stub --entry main scripts/dst/driver_plus_compose_dst.ail           > driver_plus_compose.raw

cat *.raw | grep '^CLASSIFICATION ' | awk '{print $4,$5,$6,$7,$8,$9}' | sort | uniq -c | sort -rn
```

All three exit PASS with zero `✗` rows. The fold:

```
  20  effect_free          declared_row           assumed   not_applicable not_applicable not_applicable
  16  world_mediated       ext_ambient_inventory  measured  vacuously      vacuously      substantively
   2  world_mediated       discovery              measured  vacuously      vacuously      substantively
   1  world_mediated       discovery              measured  substantively  substantively  substantively
   1  explicitly_excluded  disclosure             assumed   not_applicable not_applicable not_applicable
```

Per profile: `driver_only` **0** lines, `driver_plus_no_ops` **32**, `driver_plus_compose` **8**.

### 2.2 The four computed numbers

**1. Forty classification entries exist in this project, across three profiles.**

**2. Nineteen of them are criterion-2 (`world_mediated`) entries. Eighteen satisfy the ports and
origin-tag clauses VACUOUSLY. One does not.** That one is:

```
CLASSIFICATION compose on_response_intercept world_mediated discovery measured
               substantively substantively substantively
```

**3. Twenty-one of forty entries rest on an ASSUMED basis** — 20 `effect_free`/`declared_row`
(criterion 1's evidentiary basis, whose amendment is DRAFT and on the register) plus the one
`explicitly_excluded`/`disclosure`. **Nineteen rest on a MEASURED one.**

**4. Therefore: exactly ONE of forty classification entries in this project rests on a basis that is
both measured and substantive.** `compose` · `on_response_intercept` · basis `discovery`, under
`driver_plus_compose` v1.

**That single number is the computed answer to the question S21 was written to ask — *what does this
green table actually rest on*.** It is not a small number by accident and it is not a defect: clause
1 asked for *a* demonstration and this is it. Stating it as one-of-forty is the difference between
reporting the demonstration and overclaiming from it.

The profiles' own `STATEMENT` lines say the same thing in their own words:

```
STATEMENT extension-model coverage is NON-ZERO: 7 hook(s) covered across 1 installed extension(s),
  of which 1 mediate the world SUBSTANTIVELY through a D1 port and 2 satisfy criterion 2 vacuously.
STATEMENT extension-model coverage is NON-ZERO and ENTIRELY OF NO-OPS: 32 hook(s) covered across 4
  installed extension(s) — 16 on criterion 1 and 16 on criterion 2, of which 16 satisfy criterion 2's
  port and origin-tag clauses VACUOUSLY, i.e. over an empty set of performed effects. ZERO covered
  hooks mediate the world substantively …
```

`driver_only` emits no `STATEMENT` line at all — see §4.3.

### 2.3 The register: every surviving exemption, what it leans on, what un-leans it

**D5 counted four leanings on the empty install list. All four still exist. Three had their GROUND
replaced by a measurement, and none was removed.**

| Row | D5's leaning | State at HEAD | What un-leans it | What survives |
|---|---|---|---|---|
| **3** | the pass is vacuous in every installed-extension clause | **clauses 1, 2, 2b and 4 are non-vacuous** in `driver_plus_no_ops` and `driver_plus_compose` | D14 (floor, ids over 4 extensions) · D27 (first non-empty `excluded`, exclusion rule, disclosure agreement) | **clause 3 is vacuous in ALL THREE profiles** — see §4.2. And no run reaches an excluded dispatch; that clause is fixture-only |
| **4** | the `extension_effect_fault` waiver is bought by the empty install list | waived in all three, on **three different grounds**: construction · measured inapplicability · a per-field fact | D14 (`ext_ports_calls=0`, measured) · D27 (`ai_step_calls=0`, per field, with an effectful extension installed) | **the class is waived by every profile in the tree.** No profile exercises it. Un-leaned by nothing; needs a profile installing `compaction_ai` (priced at D27 §10.3) |
| **5** | transferability is bought by the empty install list | **re-earned on ROUTING**: compose's intercept calls `clock_now` through `ExtPorts` | D19/D26 (0 ambient `Clock` sources in any compose hook path) · D27 (first install set that reads a clock) | the routed-set claim is `7 = 6 + 1` in **all three** profiles — **installing extensions added no reachable core site in any of them.** The row's extension dimension rests on ONE routed clock read in ONE profile |
| **7** | the `ScratchpadResult` exemption is bought by the empty install list | **re-earned twice**, on grounds that are not emptiness in either successor | D14 (`provided_tools: []` + `Delegate`, two independent facts) · D27 (slot EXCLUDED + no `scratchpad` tool, two more) | **both variants still never reach the returned trace**, and the row still passes on D2's stated reading. `SessionSuspend` was never about extensions and still is not |

**Two further vacuities the fold surfaces, neither of which any row's prose owns:**

| Entry | What it leans on | What un-leans it |
|---|---|---|
| **18 of 19 criterion-2 entries satisfy the ports and origin clauses vacuously** | 16 rest on `ext_ambient_inventory` reporting **zero `ExtPorts` field calls** in the four no-op closures — vacuity over an empty set of performed effects, which the profile calls by name. 2 more are compose's `on_pre_step` and `on_solver_candidate`, which the run dispatched without them performing a mediated effect | one entry, `compose`/`on_response_intercept`. Nothing else in the tree |
| **21 of 40 entries rest on an ASSUMED basis** | criterion 1's `declared_row` basis (`ADR:1415`), and the one `disclosure`-based exclusion | nothing. `DRAFT-amendment-adr-001-criterion-2-evidentiary-basis.md` is drafted, unlanded, and on the register |

**And the thing S21 exists to catch happened again, in a new place.** D5 found the fourth leaning by
asking of each surviving exemption why it survives. This fold found the fifth the same way, and it
is not a profile's vacuity at all — it is a **producer's** (§4.2). A vacuity whose reason belongs to
a tool rather than to an install list is invisible to every per-profile question anyone has asked so
far, which is exactly the shape S21 describes.

---

## 3. THE CLASSIFICATION TABLE — FIFTEEN ROWS, COMPUTED

Goal-line clause 2: every extension **mediated** or **disclosed with a measured reason**, no
UNRESOLVED cell without a disclosure attached.

**Producers, both run in this session at `b3953a9`:**

```bash
python3 tools/ext_ambient_inventory/derive.py --json    # closure unit; source_revision in the output
python3 tools/ext_ambient_inventory/derive.py --hook-scope   # == make ext_hook_scope
```

`make ext_ambient_inventory` inside the sweep prints
`RESULT: PASS -- 15/15 extensions resolved, 18/18 std modules resolved, 0 unresolved symbols.`
The hook-scope yields are unmoved: **HOOK-PORT-MEDIATED 5 of 15 · HOOK-AMBIENT 2 · HOOK-UNRESOLVED
8**, against the closure unit's **PORT-MEDIATED 4 of 15 · AMBIENT 11**.

**Both units appear on every row where they differ. Presenting both requires no promotion decision,
and the promotion stays on the register where D15 left it.**

### 3.1 The table

| # | Extension | Closure unit | Hooks unit | Disposition | Evidence, and the class of each disclosure |
|---|---|---|---|---|---|
| 1 | **a2a** | AMBIENT (6) | HOOK-AMBIENT (2) | **disclosed** | *Hook path, unrouted:* `a2a.ail:4 std/net.httpPost {Net}`, `a2a.ail:6 std/rand.uuid4 {Rand}`, both in `on_tool_handle`. *Registration (4):* `a2a.ail:4 std/net.httpGet {Net}` — **a network GET at registration**, `config.ail:3 fileExists/readFile {FS}`, `register.ail:3 getEnvOr {Env}`. No profile installs it |
| 2 | **ailang_docs** | AMBIENT (4) | **HOOK-UNRESOLVED** | **disclosed** | *Door 3:* `show` applied at `packages/motoko-ext-mcp/exec.ail:6`, resolves to no declaration, import or builtin with producer evidence → filing `fb_0f70d66af0fddb2c` (§5). *Hook path, via mcp:* `assets.ail:13 std/package.assetPath {FS}`, `exec.ail:6 std/process.exec {Process}`. *Registration (2):* `ailang_docs.ail:4 fileExists {FS}`, `register.ail:3 getEnvOr {Env}` |
| 3 | **compaction_ai** | AMBIENT (2) | **HOOK-UNRESOLVED** | **disclosed** | *Door 3:* `show` at `compaction_ai.ail:5` → filing. *Hook path:* none — zero hook-reachable ambient sources, and **1 `ExtPorts` field call** (`ai_step`). *Registration (2):* `register.ail:6 getEnvOr {Env}`, `register.ail:9 readFileResult {FS}`. D27 §10.3 prices this as the next installable extension |
| 4 | **compaction_structural** | **PORT-MEDIATED** (0) | **HOOK-UNRESOLVED** | **mediated (closure) · disclosed (hooks)** | The row where the two units disagree most, and the disagreement is D15's finding. *Door 3:* `show` at `compaction_structural.ail:2` → filing. Zero ambient sources of any kind. **Installed in `driver_plus_no_ops` v9, whose basis is the closure verdict** — the hooks unit is reported, not relied on |
| 5 | **compose** | AMBIENT (8) / **36 `ExtPorts` field calls** | **HOOK-UNRESOLVED** (18 field calls) | **mediated on dynamic evidence · disclosed on everything else** | **The model cell.** *Mediated:* `CLAIM clause1 extension_effects=1 origins=[compose] replayed=1 mismatches=0` under `driver_plus_compose` v1, basis `discovery`, **EXISTENTIAL — it witnesses what this run performed, it does not bound what compose could do.** *Disclosed, 8 sources in three classes:* four `println` by decision (`ai_compat.ail:45`, `author_loop.ail:4`, `claimcheck.ail:4`, `compose.ail:31`), one ambient AI by decision (`ai_compat.ail:44 std/ai.stepWithStream {AI}`), three registration (`config.ail:3 fileExists/readFile {FS}`, `register.ail:3 getEnvOr {Env}` — the three `DISCLOSED registration` lines, checked bidirectionally). *Doors:* `show` at 8 sites, `intToFloat` at `ai_compat.ail:4`, **and one `applied-local`** at `ai_compat.ail:6` (§3.3). *Tool path EXCLUDED* (`on_tool_handle`, on ambient-AI grounds) |
| 6 | **context_mode** | AMBIENT (6) | **HOOK-UNRESOLVED** | **disclosed** | *Door 3:* `show` at `context_mode.ail:7` and `exec.ail:6` → filing. *Hook path, unrouted (3):* `exec.ail:6 std/process.exec {Process}` in `on_solver_candidate`; `context_mode.ail:6 std/sem.store_frame` and `load_frame {SharedMem}` in `on_tool_handle`. *Registration (3):* `prompts.ail:3 fileExists/readFile {FS}`, `register.ail:3 getEnvOr {Env}` |
| 7 | **decision_framework** | **PORT-MEDIATED** (0) | **HOOK-PORT-MEDIATED** | **mediated** | Both units agree. Zero ambient sources, zero registration-only sources. Installed in `driver_plus_no_ops` v9, 8 hooks covered |
| 8 | **empty_stop_guard** | **PORT-MEDIATED** (0) | **HOOK-PORT-MEDIATED** | **mediated** | Both units agree. Zero ambient, zero registration-only. Installed in `driver_plus_no_ops` v9 |
| 9 | **exa_search** | AMBIENT (5) | **HOOK-UNRESOLVED** | **disclosed** | *Door 3:* `show` at `packages/motoko-ext-mcp/exec.ail:6` → filing. *Hook path, via mcp (2):* `assets.ail:13 assetPath {FS}`, `exec.ail:6 exec {Process}`. *Registration (3):* `prompts.ail:3 fileExists/readFile {FS}`, `register.ail:3 getEnvOr {Env}` |
| 10 | **mcp** | AMBIENT (3) | **HOOK-PORT-MEDIATED** | **mediated (hooks) · disclosed (registration)** | The two units disagree and the hooks answer is the stronger one: **all three ambient sources are registration-only** — `mcp.ail:3 fileExists/readFile {FS}`, `register.ail:3 getEnvOr {Env}`. Zero hook-reachable ambient sources |
| 11 | **microrag** | AMBIENT (2) | **HOOK-UNRESOLVED** | **disclosed** | *Door 3:* `show` at `register.ail:10` → filing. *Hook path (2), and this is the fail-open case D15 named:* `register.ail:31 std/process.exec {Process}` and `register.ail:32 std/fs.writeFile {FS}` are bound to `on_tool_handle` **through a named function inside the registration module**, so the split must be reachability-granular and never file-granular. **Zero registration-only sources** |
| 12 | **omnigraph** | AMBIENT (5) | **HOOK-UNRESOLVED** | **disclosed** | *Door 3:* `show` at `exec.ail:6` → filing. *Hook path (1):* `exec.ail:5 std/process.exec {Process}`. *Registration (4):* `prompts.ail:3 fileExists/readFile {FS}`, `register.ail:3 getEnvOr {Env}`, `register.ail:4 std/extension.requireWorkdirFile {FS}` |
| 13 | **progress_contract_guard** | **PORT-MEDIATED** (0) | **HOOK-PORT-MEDIATED** | **mediated** | Both units agree. Zero ambient, zero registration-only. Installed in `driver_plus_no_ops` v9 |
| 14 | **scratchpad** | AMBIENT (2) | HOOK-AMBIENT (1) | **disclosed** | *Hook path (1):* `src/core/env_client.ail:21 std/net.httpPost {Net}` in `on_tool_handle` — the scratchpad loopback, a standing register entry (`tool_envelope_dispatch.ail:44`). *Registration (1):* `register.ail:3 getEnvOr {Env}` |
| 15 | **test_dummy** | AMBIENT (1) | **HOOK-PORT-MEDIATED** | **mediated (hooks) · disclosed (registration)** | Units disagree; the single ambient source is registration-only — `register.ail:12 getEnvOr {Env}`. Zero hook-reachable ambient sources |

### 3.2 The tally, and clause 2's acceptance

- **Mediated on the hooks unit: 5 of 15** — `decision_framework`, `empty_stop_guard`, `mcp`,
  `progress_contract_guard`, `test_dummy`.
- **Mediated on the closure unit: 4 of 15** — `compaction_structural`, `decision_framework`,
  `empty_stop_guard`, `progress_contract_guard`. The two sets are **not nested**: hook scope adds
  `mcp` and `test_dummy` and drops `compaction_structural`.
- **Mediated on dynamic, existential evidence over a recorded run: 1** — `compose`.
- **Disclosed with a measured reason: all fifteen carry at least one disclosure**, and the ten that
  are not mediated on either unit close entirely by disclosure.
- **Zero bare UNRESOLVED cells.** All eight HOOK-UNRESOLVED rows close by disclosing the door, its
  measurement, and the upstream filing.

**Forty-four ambient sources across the fifteen closures, in four classes, every one with a file,
line, symbol and effect set:**

| Class | Sources | How it closes |
|---|---|---|
| **registration effects** | **26**, across 10 extensions | The per-process capability measurement that already exists (S22/D6/D13): AILANG capabilities are per PROCESS and registration runs before any hook dispatches, so no routing can reach them. `driver_plus_compose` discloses its own three bidirectionally against classifier 3's list. The `registration_effects` ADR amendment stays DRAFT on the register |
| **hook-path ambient, unrouted** | **13**, across 7 extensions | Measured and named per site; no profile installs any of the seven, so none is reachable in a conformant run. Disclosure, not rescue |
| **`println`** | **4**, all compose | By decision — the goal line's own enumeration |
| **ambient AI** | **1**, compose | By decision — and it is why `on_tool_handle` is EXCLUDED in `driver_plus_compose` |
| — | 44 total | |

**And the doors, which are not ambient sources but rejections:**

| Door | Sites | Blocks |
|---|---|---|
| **`show`** (door 3) | **15 distinct applied sites**, in 16 rejection records — `packages/motoko-ext-mcp/exec.ail:6` is shared by `ailang_docs` and `exa_search` | 8 extensions — `ailang_docs`, `compaction_ai`, `compaction_structural`, `compose`, `context_mode`, `exa_search`, `microrag`, `omnigraph` |
| **`intToFloat`** | 1 — `ai_compat.ail:4` | compose only |
| **`applied-local`** | 1 — `ai_compat.ail:6` | compose only — see §3.3 |
| | **17 distinct rejection sites in total** | |

The producer's labelled counterfactual, quoted as a counterfactual: *"were these resolved
effect-free, HOOK-PORT-MEDIATED would be 7 of 15, adding `compaction_ai`,
`compaction_structural`."* **That is not a verdict and nothing in this note treats it as one.**

### 3.3 The sibling door the eight do not all rest on

The handoff asked which sibling doors the 8 rest on. **Seven of the eight rest on `show` alone.**
Compose rests on three:

```
unknown-callee  packages/motoko-ext-compose/*.ail         `show` is applied at 8 sites (compose.ail:9,
                                                          authoring/dispatcher.ail:4, prompts.ail:2,
                                                          claimcheck.ail:22, author_loop.ail:2,
                                                          store.ail:4, author_tools.ail:19,
                                                          ledger.ail:5) and resolves to no
                                                          declaration, import or builtin with
                                                          producer evidence
unknown-callee  packages/motoko-ext-ai-compat/ai_compat.ail:4   `intToFloat`, same shape
applied-local   packages/motoko-ext-ai-compat/ai_compat.ail:6   `.handle_stream_chunk(...)` is a
                                                          field call on a value this tool cannot
                                                          resolve to an `ExtPorts`-typed receiver
```

**The third is a different door and it is not door 3.** It is a receiver-resolution limit in the
tool, not a language-builtin limit in the toolchain, so the upstream filing does not cover it and
must not be read as covering it. It changes no verdict — compose is HOOK-UNRESOLVED on `show`
regardless — but a reader who closes door 3 and expects compose to clear would be wrong. Register.

---

## 4. FINDINGS THIS RERUN PRODUCED

**All six are REPORTED and go to the maintenance register. None is fixed here.** The closing note
measures the tree as it stands, not as one more item could make it.

### 4.1 The fault catalogue's condition names `driver_only` verbatim — now recorded by three profiles

Not new (D14 found it, D27 recorded it as the third), but this rerun is the fourth artefact to
carry it and it is worth the count: **two of three profiles record a waiver sentence about a
different profile**, because the machinery requires a verbatim match against a catalogue string
that hard-codes one profile's name. Register.

### 4.2 Row 3's clause 3 is vacuous in all three profiles, and its vacuity belongs to a PRODUCER

`CLAIM row3c … =0` in both successor profiles, and `profile_definition` says it outright:
`! note: check 3 is now VACUOUS (zero classifier-2 member call sites). This check, not that one, is
what holds the omission.` The classifier-2 member set has been empty since WI-B2b, so the clause
*"no installed extension calls a classifier-2 `ExtPorts` field"* quantifies over an empty predicate
in every profile — **and would do so even for a profile that installed all fifteen.**

**This is a fifth leaning, and it is the first one that is not bought by any install list.** Every
per-profile question the project has asked would return "non-vacuous" for this clause forever,
because the profile is not where the emptiness lives. The instrument already says so on every run;
what did not exist was anything that counted it. Register.

### 4.3 `driver_only` emits no coverage statement at all — neither machine-readable nor prose

`driver_only_dst.ail` prints **zero** `CLASSIFICATION` lines and **zero** `STATEMENT` lines, and
the string `coverage` does not appear in its output. The zero-coverage branch of
`coverage_statement` exists and is fixture-tested (`dst_profile.ail:2043` asserts
`startsWith(coverage_statement(fixture_base()), "extension-model coverage is ZERO")`), and
`driver_only`'s record carries `hook_classifications: []` (`dst_driver_only.ail:677`) — so the
statement is computable for it and simply is not emitted. The mandatory zero-coverage sentence
survives only as prose, inside `run_declared_vs_performed.sh`'s epilogue.

**D5's own correction 4 asked for exactly this as a checked artifact** — *"'what the label does not
assert' needs to be a checked artifact, not prose"*. The two successor profiles were built with the
mechanism; the baseline never got it retrofitted. Register.

### 4.4 Two figures inherited from D27 §10 are off, and both are corrected by re-derivation

**(a) §10.1's "identical shape across all three scripts" is two scripts, not three.** Correcting it
so the next reader does not go looking for a `driver_only` line. **The fields agree exactly between
the two scripts that emit them — which is what makes the fold legal** — and `driver_only`'s absence
is a genuine vacuity (nothing installed, nothing to classify), not schema drift. **The
stop-condition the handoff named for schema drift did NOT fire.**

**(b) §10.2's "twelve extensions have no profile and no dynamic evidence" is two figures collapsed
into one, and neither is twelve.** Re-derived from the profiles' own `INSTALLED` lines: the union of
every install list in the tree is **five** extensions — `compose` under `driver_plus_compose`, and
`compaction_structural`, `decision_framework`, `empty_stop_guard`, `progress_contract_guard` under
`driver_plus_no_ops` — so **ten** are installed in no profile. And only `compose` has dynamic
evidence, so **fourteen** have none. S22's shape, in this role's own inherited prose: a count taken
from memory rather than from a producer. Nothing turns on it; the note above uses 10 and 14.

### 4.5 Compose's HOOK-UNRESOLVED rests on a third door the filing does not cover

§3.3. Register.

### 4.6 One seeded-generator digest moved between D5 and HEAD

`722021275` where D5 recorded `2144863192`, at the same `n=23`, in the same positional order, and
with the **second** digest byte-identical to D5's (`1372950750`) — which is what makes the
identification of the moved member safe rather than assumed. Expected across the twenty-three items
between D5 and this one, and recorded only so that no future note quotes D5's constant forward as
if it were pinned. Not a defect; not fixed.

---

## 5. THE UPSTREAM FILING FOR DOOR 3 — SUBMITTED

**Filed this session through the established channel** (the `ailang-feedback` skill's channel 3,
the public `submit_feedback` MCP endpoint — the same route the project used for the recorded-stream
request).

```
ticket_id: fb_0f70d66af0fddb2c
queued_at: 2026-08-09T17:53:32Z
status:    queued
category:  limitation
title:     No producer-visible way to classify non-underscore language builtins
           (`show`, `intToFloat`)
```

**The ask:** a machine-readable way to resolve a non-underscore language builtin to the same
evidence `ailang.iface/v1` already gives for a `std/*` export — a declaration and an effect row.
Three shapes offered, the first preferred because the classifier already reads that schema: an
`iface.json` for the prelude/builtin namespace; an `ailang iface --builtins` mode; or a documented,
versioned list.

**The measurement carried in the filing, re-run in this session rather than quoted from D15:**

- `ailang check repro.ail` accepts a four-line module applying `show`, and `ailang iface` on it
  emits a clean `ailang.iface/v1` document in which **`show` appears nowhere**.
- **553 cached `std__*/iface.json` files in this checkout, and zero carry a `show` entry** —
  parsed, not grepped textually.
- `ailang iface` takes a module path and has exactly one flag (`-compact`); there is no builtins
  mode.
- D15's discarded textual route is described in full, including that it resolved `f`, `p`, `pred`,
  `get`, `put` and `cas` as "language builtins" and classified `f` EFFECTFUL and `p` PURE. **A rule
  that invents evidence is worse than one that reports its absence** — that sentence is in the
  filing, because it is the reason the door is disclosed rather than worked around.

**The scratch repro was deleted after measurement; `git status` is clean.** The table's eight
door-3 cells cite this ticket.

---

## 6. THE NAME DECISION

**YES. The label stands for the generated axis, and `driver_plus_compose/1` is the profile that
changes what it rests on.**

D5's verdict was YES on eleven green rows for `driver_only/10`, with a mandatory sentence saying
the axis's extension-model coverage was ZERO. **That sentence is now false and the reason it is
false is a demonstration rather than an argument.** Extension-model coverage is non-zero, measured:
32 covered hooks across four extensions under `driver_plus_no_ops` v9, and seven covered plus one
excluded under `driver_plus_compose` v1, of which exactly one mediates the world substantively —
a real graded session through the real traced driver, with compose installed through its own
`register_with_config`, performing a world-mediated effect that is origin-tagged to `compose`,
present in the recorded program, and reproduced by a strict replay under the recorded manifest with
zero mismatches.

**What the answer rests on, in one paragraph.** It rests on eleven acceptance rows that were run in
this session and not read forward; on a demonstration that cannot pass vacuously, because it either
recorded an origin-tagged effect and replayed it or it did not, and D27's mutant A shows the row
going red when the subject is removed; on fifteen extensions each classified by a producer that
names its own source revision, with every non-mediated one closed by a disclosure carrying a file,
a line, a symbol and an effect set; and on a vacuity register that this note computes rather than
narrates and that comes back with **one of forty** classification entries on a measured, substantive
basis. It does **not** rest on the register being empty — the goal line renounced that, and the
register is not empty. It does not rest on door 3 being closed; door 3 is disclosed and filed. It
does not rest on compose being classifier-clean; classifier 3 still reports compose AMBIENT with
eight sources, and the profile asserts that no classification cites it. **And it does not rest on
the compose profile's evidence bounding what compose could do** — `discovery` is EXISTENTIAL, every
cell citing it says so, and a reader who takes clause 1 as a universal claim about compose has made
exactly the error this note's §3.1 cell was written in that shape to prevent.

**What the label asserts, restated at HEAD:** the generated axis generates executions from seeds
rather than values; models provider, typed tool execution, approval, clock, environment,
filesystem and logical resource state in one state-threaded world; injects logical faults reaching
nine named production recovery branches; routes every profile-reachable time-bearing read through
the world clock, and re-earns that on routing rather than on absence in the one profile whose
install set reads a clock; runs the real driver, now with an installed effectful extension inside
it; returns a trace complete over every emission the axis produces, on a stated reading; separates
harness failures from production outcomes; replays exactly under a recorded manifest, including a
session with an installed extension; enforces hermeticity **per profile**, with five two-sided
poison pairs for the driver and a stated boundary where a profile grants capabilities across
registration; and searches with a bounded corpus meeting an operator-accepted minimum.

**What the label still does NOT assert — the successor to D5's mandatory sentence, and it is
mandatory in every report from here:**

> **The axis's extension-model coverage is NON-ZERO and it is one hook deep.** Three profiles
> exist; forty hook classifications exist; **exactly one of them rests on a basis that is both
> measured and substantive**, and its basis is EXISTENTIAL — it witnesses what one recorded run
> performed, and bounds nothing about what any extension could do on inputs that run did not
> supply. **Ten of the fifteen extensions are installed in no profile, and fourteen of the fifteen
> have no dynamic evidence of any kind.** What has been tested about the extension model is one
> mediated hook in one session, and nothing in this verdict says otherwise.

**Row 7 remains the single interpretive dependency in the table**, exactly as D5 reported it. If a
reviewer rejects the reading that *"logical ledger emissions"* means emissions the axis can produce,
row 7 is red and this verdict is NO.

---

## 7. MECHANIZATION — DECIDED, AND WHY

**No permanent aggregator was built. The fold commands are printed verbatim in §2.1 and §3, and
they derive from the profiles' own printed lines rather than pinning copies of them.**

The reason is the one the item stated: a one-shot closing document does not require permanent
machinery, and an instrument built this late becomes the item. Three further reasons, measured:

1. **The fold is four lines of `grep`/`awk`.** Its whole content is `sort | uniq -c` over nine
   whitespace-separated fields whose shape is asserted by the two scripts that emit them.
2. **A permanent aggregator would need a home in the sweep**, which means another consumer in the
   anchor cascade — which D27 joined at eleven files — and a fixture set of its own, priced at more
   than the artefact it produces.
3. **The thing worth mechanising is not the fold.** §4.3 is the real gap: `driver_only` does not
   emit its own coverage statement. A register entry that adds one `STATEMENT` line to one script
   would make the aggregate computable from three profiles instead of two, and *that* is the
   instrument to build in the taper — not a script that folds lines two of three profiles print.

**Both routes are honest. This one is stated rather than assumed, which is the part that matters.**

---

## 8. GATE STATE — RUN, NOT REPORTED

**`make dst`, logged to a file rather than piped, no tracked file touched while it ran** (and no
other `ailang` invocation started until it finished — the fold in §2.1 and the door-3 repro in §5
both ran afterwards). `2026-08-09T17:35:10Z` → `17:50:37Z`, **1029 `✓` rows**. Cache state is as
recorded in §0: four cleared before the run, out of 48 in the tree.

**EXIT 2. The red set is exactly two targets and both are standing reds pinned to HEAD before this
item:**

| target | finding | pinned since |
|---|---|---|
| `test_coverage` | `prompts_test.ail` 6 of 6 failed; `stale_skip_record` "Named test blocks not yet implemented" | D22 |
| `test_coverage_selftest` | 2 failures — `stale_skip_record` on an unexpected subject; `named_only.ail` also fired `failing` | D22 |

**Nothing else in the sweep is red.** Every other named target passed, individually verified in the
log: `compaction_dst`, `conformance`, `phase_c_l1`, `terminal_trace`, `world_state`,
`profile_coverage`, `profile_definition`, `driver_only`, `driver_plus_no_ops`,
`driver_plus_compose`, `fault_catalogue`, `event_vocabulary`, `invariants`, `run_report`,
`latency_pair`, `corpus_pr`, `corpus_rotating`, `attribution_table`, `execution_program`,
`discovery`, `compose_live_exec`, `strict_replay`, `seeded_generator`, `program_persistence`,
`predicate_anchors`, `ext_call_inventory`(+selftest), `ext_ambient_inventory`(+selftest),
`ext_hook_scope_selftest`, `recorded_stream`, `stream_parity`, `ledger_parity`,
`declared_vs_performed`, `hook_guard`, `smoke_driver`, `smoke_parity`, `dst_l2`, `dst_seeded`.

**The third standing red, run separately because it is not in the `dst` aggregate:**

```
$ make effect_inventory_selftest
FAIL: the self-test compared ZERO modules, so it certified nothing.
      `ailang iface` produced no parseable interface for any stdlib
      module … This is a pass-shaped absence, not a pass.
self-test: agree=0 disagree=0
```

Unchanged since D25. **The gate is refusing an absence, correctly.**

### 8.1 Final states, all by run

| | |
|---|---|
| profiles | `driver_only` **v22** · `driver_plus_no_ops` **v9** · `driver_plus_compose` **v1** — none re-issued |
| profile rules | **`profile-rules/3`**, 4 measured producers (`discovery`, `effect_inventory`, `ext_ambient_inventory`, `ext_call_inventory`), 2 deliberately assumed (`declared_row`, `disclosure`) |
| classifier 3, closure | **PORT-MEDIATED 4 of 15 · AMBIENT 11**; compose **8 ambient sources / 36 `ExtPorts` field calls** |
| `ext_hook_scope` | **HOOK-PORT-MEDIATED 5 of 15 · HOOK-AMBIENT 2 · HOOK-UNRESOLVED 8** |
| inventory | `RESULT: PASS -- 15/15 extensions resolved, 18/18 std modules resolved, 0 unresolved symbols` |
| barriers | **33 of 45 (extension, slot) pairs stand**; zero remain for the same four extensions; all 3 stand for compose |
| ABI | **5.0**, 15 rows + 5 added types, **10 sites across 6 files** (glob-derived since D27) |
| anchors | `✓ no drift: 6 anchors and 7 references all match their accepted hashes` |
| `declared_vs_performed` | **46 passed, 0 failed** |
| `hook_guard` | **4 passed, 0 failed** · `smoke_driver` **0 failed** |
| attribution ref | `(c0fbf10, sha256:753839ba…4a34bc)` — current for all three profiles |
| classification entries | **40** total: 20 `effect_free`, 19 `world_mediated`, 1 `explicitly_excluded` |

### 8.2 The counters

- **Silent-wrong: 76 across 49 runs. UNMOVED.**
- **Instrument-weaker-than-its-claim: 7. UNMOVED.**

**This item wrote no production code.** It ran gates, read their artifacts, folded printed lines,
and submitted one upstream filing. There was no site at which two answers could type-check, so
neither counter has a candidate. The two stay strictly apart, as they have since D21.

**And per S20, this is again a run where reproduction would be reassuring about the wrong thing.**
Most of the figures above match D5's or D27's exactly — and §4.6 records one that does not, which is
the more instructive case. Reproducibility is precisely what D4 proved can hold while the property
it appears to confirm is false. **What makes these numbers trustworthy is not that they match a
previous note's; it is that each was derived by a producer that names its own revision** —
`derive.py`'s `source_revision`, the profiles' computed routed-set claims, the ABI's glob-derived
site scan, the anchor hashes.

---

## 9. THE TAPER — THE TRANSITION THE GOAL LINE PRESCRIBES

**THE GOAL LINE IS REACHED. BOTH CLAUSES HOLD.**

1. **The demonstration.** `driver_plus_compose` v1 records a real graded session with compose
   installed and replays it deterministically, with non-vacuous criterion-2 evidence:
   `extension_effects=1 origins=[compose] replayed=1 mismatches=0`.
2. **The disclosure table.** All fifteen extensions are mediated or disclosed with a measured
   reason. Zero bare UNRESOLVED cells. Door 3 closes by disclosure plus filing
   `fb_0f70d66af0fddb2c`.

**The loop now INVERTS, by the decision recorded in the plan's goal-line section.** The maintenance
register becomes the queue's only source, ordered by measured value, at reduced cadence.
Continuation is explicitly **maintenance, not pursuit**. Standing rules are earned only by
exception. The counters continue as fix-or-file, still separate.

### 9.1 The maintenance register at its closing state — **NINETEEN entries**

**The list below is numbered continuously and its last index IS the count.** An earlier draft of
this section numbered only two of its four blocks, so the last index read 16 while the count was
19 — and the number that a reader takes from a register is the register's whole point. Corrected
here rather than left to be re-derived.

**Carried from the goal-line decision (2026-08-09, after WI-D23) — 1 to 9:**

1. The eight stale classifier-2 literals (ten items stale)
2. Classifier 1's repair
3. The gate-table State column
4. The hook-scope promotion (an ADR-scope decision, drafted at D15, not applied)
5. The scratchpad loopback successor (`tool_envelope_dispatch.ail:44`)
6. The stdlib cache's producer (open since D14 — `~/.local/share/ailang/std/.ailang`, 52 files,
   still unidentified)
7. F3
8. The bridge's `workdir`/`timeout_ms` hardcoding — **inert for `BashExec`** (D26: `run_process_result`
   never receives `workdir`, so a routed call runs where the process started)
9. The four-variant fault-class discrimination across the ABI

**Added at WI-D25 — 10:**

10. `effect_inventory_selftest`'s *"compared ZERO modules"* red — the third standing red, pinned by
    measurement.

**Added at WI-D26 — 11:**

11. The lost executable home for *"performed is a property of a hook AND its inputs"* — compose's
    intercept no longer has two inputs with two performed answers.

**Added at WI-D27 — 12 and 13:**

12. The `registration_effects` ADR amendment (DRAFT, unlanded).
13. The fault catalogue's `driver_only`-naming condition, then with three consumers — **escalated
    at WI-D28, see 14.**

**Added at WI-D28 — 14 to 19: one escalation (14), four new findings (15–18), and one standing fact
the register had never carried (19):**

14. **The catalogue's `driver_only`-verbatim waiver condition** now has **three** profiles recording
    it and two of them recording a sentence about a different profile (§4.1). Escalated from 13
    with a count.
15. **Row 3 clause 3's vacuity belongs to a producer, not a profile** (§4.2) — classifier 2's member
    set has been empty since WI-B2b, so the clause is vacuous for any profile including a
    fifteen-extension one. **The first leaning in the register that no install list can buy.**
16. **`driver_only` emits no coverage statement**, machine-readable or prose (§4.3), while its
    successors do. D5's correction 4, still open, now with a measured shape and — per §7 — **the one
    piece of mechanisation worth building in the taper.**
17. **Two inherited D27 §10 figures corrected by re-derivation** (§4.4): the `CLASSIFICATION` lines
    come from two scripts, not three; and "twelve extensions have no profile and no dynamic
    evidence" is **ten** with no profile and **fourteen** with no dynamic evidence. Corrections
    only — nothing turned on either.
18. **Compose's `applied-local` door** at `ai_compat.ail:6` is a receiver-resolution limit in the
    tool, not a language-builtin limit in the toolchain, and the upstream filing does not cover it
    (§4.5).
19. **No run in this tree reaches an excluded hook dispatch.** `hook_guard`'s four rows are fixture
    evidence and `driver_plus_compose`'s exclusion check is a validator call; the graded session
    dispatches no tool.

**And one standing fact that is NOT a separate entry, because it is row 4's register line in §2.3
rather than a new item:** `extension_effect_fault` is waived by every profile in the tree,
un-leaned by nothing, and the fix is priced at D27 §10.3 as a `compaction_ai`-bearing profile.

**Renounced, and still renounced — each with its measured reason:** 15 of 15 mediated (registration
is structurally unroutable); a producer for door 3 (disclosed and now filed); the `proc_exec` rename
and ABI `6.0` (a release decision with consumers outside this project); the ADR citation-layer
repair (~14% wrong before any edit, and correcting a layer of unknown correctness hides the decay);
and a fully non-vacuous acceptance table as the definition of done.

---

## 10. RECORDED BINDINGS

**Discovered — a tool or a measurement forced it:**

1. **Exactly one of forty classification entries rests on a measured, substantive basis.** The
   fold's headline, and the first time the project has had an aggregate answer to *what does the
   green table rest on*.
2. **Eighteen of nineteen criterion-2 entries are vacuous** — and the vacuity is a *measurement* in
   sixteen of them (`0 ExtPorts field calls` in the no-op closures), which is a different and better
   thing than an unexamined assumption.
3. **A leaning can belong to a producer rather than to a profile** (§4.2). S21's detection procedure
   found it, and no per-profile question could have.
4. **Twenty-one of forty entries rest on an ASSUMED basis**, all of them criterion 1's `declared_row`
   plus the one disclosure-based exclusion. Never counted before.
5. **`driver_only` is the only profile with no coverage statement**, and it is the one whose
   statement D5 made mandatory.
6. **Compose's HOOK-UNRESOLVED has three doors, not one.**
7. **`make dst` at HEAD is 1029 `✓` rows against D5's 845**, on the same methodology, with the same
   two-target red set.

**Decided — a human chose:**

1. **The name STANDS**, on eleven green rows plus a demonstration, with a successor to D5's
   mandatory caveat that is quantitative rather than categorical.
2. **Row 7 passes on the same reading D2 stated**, reported in the verdict rather than absorbed, so
   a reviewer who rejects it knows which row to reopen.
3. **Both classification units are presented on every row where they differ**, which requires no
   promotion decision. The hook-scope promotion stays on the register where D15 left it.
4. **Compose's cell says `mediated on dynamic evidence, EXISTENTIAL`** and never bare "mediated".
5. **No permanent aggregator was built**, and §7 says why — with the one instrument that *is* worth
   building named for the taper.
6. **Door 3 was filed, not worked around**, and the filing carries D15's discarded-route measurement
   so the upstream reader knows what was already tried.
7. **Six findings were reported and none fixed.** The closing note reports the tree; it does not
   improve it.

---

## 11. WHAT THE APPLY OWES

The reviewing session's last act on the critical path:

1. **The plan's final full-cadence milestone entry** for WI-D28.
2. **The verdict on the verdict** — independently verify this note's central claims by measurement,
   per the review protocol's one rule. The cheapest three: re-run the §2.1 fold and confirm the
   `20/16/2/1/1` distribution; confirm `driver_only_dst.ail` emits no `STATEMENT` line; confirm
   `make dst` is EXIT 2 on exactly `test_coverage` and `test_coverage_selftest`.
3. **The taper's activation in `NOTE-review-protocol.md`** — the loop's source becomes the
   maintenance register, the cadence drops, and continuation is labelled maintenance.
4. **Nineteen register entries** carried forward at §9.1, numbered continuously so the last index is
   the count — nine from the goal-line decision, one each from D25 and D26, two from D27, and six
   added here, one of which escalates a D27 entry rather than adding to it.

**Fifty-one calibration runs built and measured this axis. The fifty-second says what it rests on,
in a number, and stops.**
