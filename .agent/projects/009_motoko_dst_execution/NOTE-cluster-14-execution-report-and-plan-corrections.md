# Cluster 14 execution report — WI-A15, and a closing view of Milestone A

Fourteenth calibration run. **Both mission pieces landed, green and committed.**

Commits:

- `ff54c0f` feat(A15): piece 1 — D11's blocking PR corpus, and a corpus needs two keys
- `ee4311c` feat(A15): piece 2 — D11's scheduled rotating corpus, and the coverage swap

**`make dst`: exit 0** — read as an exit status — at **700 green checks**, against 591 at the
item's start. **`make check_core`: exit 0**, 51 modules (50 before). The single `✗` in the `dst` log
is the `✗ Failed: 0` summary label of a passing `ailang test` run, checked rather than assumed.

No source drift at session start (`git diff --stat 3dd8a82..HEAD -- src packages scripts Makefile`
was empty).

**A5 anchors undisturbed.** `stub_step.ail:161` and `session.ail`'s 948/1053/2290/2400 verified
intact at start and end; `driver_only` stays at **v3**. Nothing this item added touches those files —
the sixth consecutive item to pay zero anchor cost, and the second to do so by not needing to.

---

## Correction 0, and it is the one that changes what happens next

**A15 IS NOT THE LAST ITEM IN MILESTONE A, and the handoff, the plan's cluster map and this item's
own commit messages all say it is.**

The cluster map's own last row says otherwise and has since cluster 4:

| — | **A17** | `Makefile`/CI; the `ailang test` coverage axis | — | **Groundable now, standalone, parallelisable.** Small; unassigned to a cluster since cluster 4 spawned it |

**A15 is the last item on the CRITICAL PATH** (1 → 6 → 7 → 8 → 9). A17 is off it, was spawned by
cluster 4 rather than planned, was never assigned a cluster, and is still open. Every subsequent
handoff inherited "A15 is the last item in Milestone A" from the sentence before it and nobody
re-read the table two rows down.

**This is worth more than the correction.** A17 is the item that checks *whether inline tests run at
all* — cluster 4 found `session.ail`'s 21 tests and `phase_vocab.ail`'s 27 executed by nothing — and
it went unassigned for ten clusters *because it was spawned rather than planned*. An item that
enters the plan sideways does not acquire a cluster, and nothing in the process notices. The cluster
map has a row for it; the milestone-completion sentence does not read the cluster map.

Milestone A is **one item short**, and it is the item that guards the other sixteen.

---

## The decision this item owned, and the handoff's prescription was half right

### The corpus needs TWO keys, and `artifact_identity` is not the one that fixes site 22

The handoff and the plan both say: key the corpus on `dst_persistence.artifact_identity`, **because**
the `(generator_id, generator_version, seed)` triple aliases under site 22 — `seed_state` is
`in_range(salt_hash("${id}/${version}") + seed)`, so version and seed are *added* and version `"2"`
at seed *s* is the same stream as version `"1"` at seed *s+1*.

The premise is right and the conclusion does not follow. Measured at HEAD, 30 adjacent
(v2, *s*) / (v1, *s+1*) pairs run through the real driver:

| | |
|---|---|
| identical **trajectory** — same interactions, draws, clock, byte length | **29/29** |
| identical **`artifact_identity`** | **0/29** |

**The identities differ because `generator_version` is a field inside the encoded bytes.** Keying on
the identity cannot merge site 22's aliases; the two artifacts genuinely *are* different bytes.

So the two keys answer two different questions:

- **`artifact_identity` — addressing.** Deduplicates one program filed twice, and *separates* two
  different programs sharing a triple. **This is the direction the plan's worked example is actually
  about**: D4's latency pair, two worlds differing in one integer, one triple, two identities. It is
  the direction that **loses** a program.
- **`trajectory_key` — coverage.** A digest of the interactions and nothing from the generator axes.
  Two members sharing it contribute one program's worth of coverage however many triples they claim.
  **This is site 22's own sentence** — "a corpus holding (v1, seed 4) and (v2, seed 3) has one
  program's worth of coverage while reporting two" — and the identity key is blind to it.

A corpus counting coverage on the identity key alone would report 29 programs where it holds 1.

**And the demonstration was rebuilt because the first one was tautological.** The alias row originally
copied a member and edited its `generator_version`, which makes the trajectory keys equal *by
construction* — the row asserted a relationship it had just created. It is now two **real driver
runs** at (v2, seed 7) and (v1, seed 8), compared after the fact. That change is worth more than the
row: the property `trajectory_key` cannot see the generator axes is **structural** (the function
takes `[Interaction]` and nothing else), so no mutant can break it — which means the only thing worth
asserting is the *measurement*, and the measurement needs two independent runs.

### The `max_resource_size` rebinding: DEFERRED, and cluster 13's ground for assigning it here is wrong

Cluster 13 resolved this as a decision and assigned it to A15 "which already re-pins seeds for its
corpora and is the cheapest place to absorb a version bump". **Three things say otherwise, and the
first is not the cost argument.**

**1. `max_resource_size` is not unlike D2's other four bounds. It is exactly like them.** Cluster 13's
premise is that it "measures nothing in a real run". Measured at HEAD, *no* honest bound binds — and
that is the *specified* behaviour, not a defect. D2 makes exceeding a bound a **generator failure**,
and `make seeded_generator` asserts *zero generator failures on the honest bounds* for every run. A
bound that fires on a legitimate trajectory turns every run red. The four others are as slack as the
fourth:

| bound | honest limit | what the generator can actually reach |
|---|---|---|
| `max_interactions` | 96 | ≤ 50, measured across 260 seeds |
| `max_payload_bytes` | 512 | ~15 bytes |
| `max_chunks_per_interaction` | 4 | a 0..3 draw |
| `max_clock_advance_ms` | 2000 | ≤ ~150 |
| `max_resource_size` | 8 | 2 |

**2. S8's complement is already discharged, by the artifact stage 5 built for exactly this.**
`canary_bounds_tight` sets every limit tight enough to bind *for every seed* — `max_interactions: 0`
specifically "so `budget_spent` is true at the first provider choice for every seed without
exception" — and the canary folds every *field* of every bound failure. The `max_resource_size`
branch is walked and pinned today. It is not an absent path.

**3. What is genuinely weak is narrower than a rebinding, and cluster 13's sizing ground runs
backwards.** The real defect is that the quantity `max_resource_size` reports has a **static range of
one value** (`requested` is always 2), where the other four report draw-derived quantities. The
repair is one draw, not a rebinding — and it still costs a generator-version bump.

And: **A15 does not *re-pin* seeds. It *pins new ones, from a sweep*.** A version bump shares no work
with that sweep; it **serializes in front of it** and makes every swept number provisional. Taken
here, the bump is prepended, not absorbed — which is the opposite of the reason it was assigned here.

**Deferred, with the instrument named.** The corpora are what make the choice measurable: the fixed
bank now reports bound-failure records per member and the rotating window sweeps a moving seed space,
so "what does `max_resource_size` report, and over what range" becomes a measured number instead of a
reading of the source. Choosing a new binding *before* that instrument existed is how the current
binding was chosen.

**Owner: the first item that touches the generator after the corpora exist.** In practice that is the
Milestone B wave, which re-sweeps anyway. **It is a one-draw item, not a rebinding**, and the
distinction is the contribution.

**The `seed_state` fix was NOT taken, and not by accident.** Fixing the version axis would move every
pinned canary row, every corpus seed and the frozen specimens' meaning at once; it is a strictly
larger change than the one-draw item and belongs with it, not before it.

---

## What landed

### Piece 1 — the blocking PR corpus (`ff54c0f`)

**`src/core/dst_corpus.ail`**, new — the two keys, `CorpusMember` and its three kinds, `CorpusJob`,
the rotation, the sharding, 20 rejection rules and the shrink-only register. **`scripts/dst/
corpus_pr_dst.ail`**, new. **`make corpus_pr`**, wired into `make dst`.

**The bank is a query's answer.** 260 seeds swept through the real driver; the bank is the union of
five *derived* selections, and each member's reason is asserted rather than described:

| seeds | why |
|---|---|
| 1, 176 | the shortest and longest eligible trajectories (n = 9 and 50) |
| 2, 3 | the two smallest reaching `approval_denied` |
| 6, 20 | the two smallest reaching `ToolCorrelationMismatch` |
| 14, 15 | the two smallest reaching `ToolDeadlineExceeded` |
| 23, 39 | the two smallest reaching `ToolFailed` |
| 114 | the richest **Err**-terminating trajectory — enters as a **promoted regression** |
| 195 | **the only seed of 260** reaching all four sweep-reachable classes alone |

**Two witnesses per class rather than one**, deliberately: a bank with a single witness loses that
class to any generator drift that moves one seed, and loses it *silently*, because the remaining
members still pass.

**The minimums are arithmetic over one measured constant** — 260 seeds in 76.0 s = **292 ms/seed** —
not literals with a comment. `pr_target_ceiling_ms()` puts a gate behind the measurement, so a
constant nobody re-measures goes red rather than stale.

### Piece 2 — the scheduled rotating corpus and the coverage swap (`ee4311c`)

**`scripts/dst/corpus_rotating_dst.ail`**, new, with **two entry points**: `main` (the acceptance
suite) and **`scheduled_run`** — the job CI actually runs. **`.github/workflows/dst-corpora.yml`**,
new: the first workflow in the tree with a generated-trajectory axis. **`make corpus_rotating`**.

**The window is shown to rotate, three non-redundant ways**, and the third is the one that matters:

1. **`rotation-position-frozen`** checks **position by position**. A window built as "a fixed prefix
   plus a rotating tail" changes at every epoch and is pinned at every prefix position; a
   whole-window comparison is green on it.
2. **`rotation-wrap-not-exercised`** is S8's complement. A sample that never crosses the end of the
   space leaves the wrap branch *absent*, and absent reads identically to unchanged.
3. **`epoch-not-resolved`** closes the leak that defeats both **without touching either**. If the
   scheduler's epoch is absent and the job defaults it, every rotation check above stays green — the
   rotation is fine; the *input* stopped arriving — and the window is frozen. `resolve_epoch` has no
   default.

**And the four failures are FORCED, not asserted.** Each is injected into the real job and the job
must exit non-zero:

```
✓ forced 'no-epoch':       the job exited 1 — [epoch-not-resolved]
✓ forced 'zero':           the job exited 1 — REJECTED: corpus-empty
✓ forced 'below-minimum':  the job exited 1 — REJECTED: window-below-minimum
✓ forced 'truncated':      the job exited 1 — REJECTED: window-truncated
```

**The rotation is also re-derived outside the process**, from `WINDOWROW` lines, because every
in-process check compares windows the same module produced.

**The coverage swap.** The register moved to `dst_corpus.unreachable_by_search()` so there is exactly
one of it — `corpus_pr_dst` asserts it against the sweep in both directions, `run_report_dst` renders
it. **Two entries closed**: A14 recorded `ToolCorrelationMismatch` and `ToolDeadlineExceeded` as
"undriven by the pinned seeds; MORE SEEDS IS THE FIX", and more seeds was the fix. A14's *three gaps,
three reasons* is now **four gaps in four distinct ways**, which is strictly stronger, and the closure
is asserted so a reopened entry cannot be absorbed silently.

---

## Correction 1 — D11's two counters have two DIFFERENT OBSERVERS, and only one of them is in-process

D11 says class-reached and branch-reached are separate counters "read from D3's catalogue artifact".
Reading both from the catalogue is right about the *ids* and wrong about the *evidence*, and the
difference is not a design choice:

- **class-reached** is observable in the recorded interaction log — the world's answer.
- **branch-reached is not observable in this process at all.** `NativeToolDenied` and
  `NativeToolResults` are both in `dst_invariants.d64_gap_register()`: they never reach the returned
  trace. The only witness is the **wire**, emitted by production code that knows nothing about the
  interaction log.

So `make corpus_pr` counts the branch from the wire, and it counts rather than greps for presence:

```
✓ wire witness, branch-reached: approval_denied×32 empty_stop_finalize×1 ToolFailed×3
  ToolCorrelationMismatch×5 ToolDeadlineExceeded×5 (against 57 executed dispatch batch(es),
  so neither side of the approval decision is unwalked)
```

**This is the real reason D11 keeps the counters separate**, and it is stronger than the reason D11
gives: they have different observers, and only one of them is independent of the recorder.

## Correction 2 — the fixed bank reaches FOUR of nine required non-waived classes by search, and the fifth is constructed

Measured over 260 seeds, of the nine required classes `driver_only` does not waive:

| reachable by a seed | 4 | `ToolFailed` (33 seeds), `ToolCorrelationMismatch` (27), `ToolDeadlineExceeded` (30), `approval_denied` (152) |
| unreachable, four different ways | 4 | the two provider-error classes, the protocol-inconsistent class, the partial-stream class |
| **unreachable by SEARCH, reachable by CONSTRUCTION** | **1** | `provider_empty_terminal_response` |

**The last one is the plan's own limit arriving where the plan predicted the shape and not the
instance.** Cluster 12 wrote that sweep-and-filter "cannot cover a space the producer does not
reach", and named the *provider fault class* as the case. The measurement adds this one: every
generated terminal step carries non-empty prose, and `session.c2_loop`'s empty-stop branch is guarded
by `trim(info.output) == ""`. Measured: **0 of 260 seeds, and 0 `empty_stop_finalize` records on the
wire across the entire sweep.**

It is covered by a **constructed** member whose justification is *checkable*:
`constructed-for-reachable-class` fires the moment a swept seed reaches it, and the Makefile requires
**exactly one** `empty_stop_finalize` on the wire — a second one means a generated seed has started
reaching the class the construction exists for.

## Correction 3 — `documented_coverage()` declared one class Reached that no seed reaches

A14's register recorded `provider_empty_terminal_response` as `Reached`. It is — by hand-authored
scenarios elsewhere in the tree — and **by no generated program at all**. The declaration was true
for a reason nobody had checked, which is the exact hazard a *declared* register carries and the
reason A14 labelled it as declared. It now records the fact it actually has.

---

## Sites 28–31 — four type-checking answers with a silent wrong one

**Thirty-one across fourteen clusters. Determinism has caught none.** Three of the four were found by
reading output and asking what it would look like if the check were empty; one was found by a guard
firing on its first run.

### Site 28 — the sweep instrument reported that no seed reaches anything

The sweep probe counted interaction kinds with `"provider"`, `"tool"`, `"approval"`,
`"environment"`, `"clock"`. `dst_interaction.identity_kind` returns `"expect_provider"`,
`"expect_tool"`, `"expect_approval"`, `"environment_read"`, `"advance_clock"`.

Every count was **0**, for every seed. The probe type-checked, ran clean, exited 0 and produced 260
perfectly formatted rows of zeros — and the *interaction totals* beside them were correct, which is
what makes it survivable: `n=9`, `n=16`, `n=17` are right, so the output looks like data.

**A bank selected from those rows would have covered nothing while reporting twelve members.** Caught
only by reading the first four rows and asking why a 17-interaction trajectory had no interactions of
any kind.

### Site 29 — `fault_class_id` is the right quantity and can only ever name three classes

The obvious class observer is `Interaction.outcome.fault_class_id`. `ports.tool_outcome_record` is
its **only writer**, so it can name `ToolFailed`, `ToolCorrelationMismatch` and
`ToolDeadlineExceeded` and nothing else. Graded by it, the sweep reports **0 of 260 seeds reach
`approval_denied`** — and 152 do.

This is **cluster 13's site 25 one level up**: the right quantity, insufficient on its own, and only
visible to a cross-check built specifically to defeat it. The class observer is now three observers,
each named at its site. **The register would have gained two false entries** — `approval_denied` and
`provider_empty_terminal_response` recorded as unreachable — and both would have been *believed*,
because a register that only ever shrinks is trusted to be conservative.

### Site 30 — the alias row asserted a relationship it had just constructed

Covered above. Found by writing a mutant (fold something extra into `trajectory_key`), watching it
**fail to fire**, and reading why: the mutant could not break the property because the property is
structural — and the row that was supposed to demonstrate the property was comparing a member with a
copy of itself. **The mutant that does not fire is as informative as the one that does**, which is
cluster 13's site 27 in the other direction.

### Site 31 — a grep-based guard matched its own comment

`make corpus_rotating` greps the workflow to prove the scheduled job does not select the demo scale.
The first version was `grep -qE 'MOTOKO_DST_SCALE.*demo'` and it went red on its first run — matching
the workflow's own comment explaining that the string must not appear.

S7's rule is **anchor a grep-based Makefile guard to a syntactic form**, and this is the fourth item
to be reminded. Anchored to a YAML mapping key at line start
(`^[[:space:]]*MOTOKO_DST_SCALE:[[:space:]]*.?demo`) it stays silent on prose and still fires on a
real selection — verified both ways.

**Two smaller ones, recorded because they are the same shape:** the corpus initially carried
`elapsed_ms: 1000`, a number the run never measured (now 0, with the Makefile measuring from outside);
and the sharded job's success line printed the *job's* minimum rather than the *shard's*.

---

## What the mutation testing found that the gates did not

**Nine mutants, nine caught after the repairs above.** The instructive one is the fourth:

| Mutant | Result |
|---|---|
| `sample_rejections()` loses the **nullary** `WindowZero` | caught by the Makefile guard |
| `all_member_kind_ids()` **drops** `ConstructedForClass` | caught — **by the suite, not the guard** |
| **`all_member_kind_ids()` samples one kind TWICE and omits another** | **suite stayed GREEN; the guard caught it by name** |
| the constructed member's terminal step gains prose | caught (target exit 1) |
| the ceiling is exceeded | caught |
| the workflow selects the demo scale | caught |
| the workflow matrix is 3 against 4 declared shards | caught |
| a window that ignores its epoch | caught — `rotation-position-frozen` |
| a sample that never wraps | caught — `rotation-wrap-not-exercised` |

**The third row is cluster 13's finding reproduced exactly.** Dropping a kind was caught by the S7
row (`List.length(kinds) == List.length(all_member_kind_ids())`), so the Makefile guard looked
redundant. Sampling one kind twice keeps the *length* at 3 — the suite row stays green, and only
membership-by-name sees it. **A count is satisfied by sampling one constructor twice and omitting
another**, and the two guards are not redundant; they are sensitive to different things.

---

## Sizing — S6 per piece, and the discovered count predicts a fourth time

**Recorded bindings: sixteen — nine decided, seven discovered.**

**Piece 1, the PR corpus (9: 4 decided, 5 discovered).**

1. *Decided.* The manifest is read out of the bytes, never supplied beside them — D11's "travel as
   one artifact" made structural rather than asserted.
2. *Decided.* The bank is a query's answer: obligations as a filter, sweep, pin the survivors.
3. *Decided.* Two witnesses per class, because one is lost silently.
4. *Decided.* A constructed member's justification must be checkable, so the register can only shrink.
5. *Discovered.* **The corpus needs TWO keys**, and the handoff's prescription fixes the other
   direction.
6. *Discovered.* **Site 29** — the class observer is three observers.
7. *Discovered.* **`provider_empty_terminal_response` is unreachable by search**, which the plan
   predicted the shape of and not the instance.
8. *Discovered.* **Branch-reached is not observable in-process at all** (correction 1).
9. *Discovered.* **Sites 28 and 30**, and the two unmeasured numbers.

**Piece 2, the rotating corpus (7: 5 decided, 2 discovered).**

1. *Decided.* Position by position, not window by window.
2. *Decided.* The wrap branch must be entered (S8's complement, stated in the plan).
3. *Decided.* The epoch fails closed rather than defaulting.
4. *Decided.* The four failures are forced, not asserted — the definition of done says so.
5. *Decided.* Shard minimums sum to the job's, which is the truncation rule one level down.
6. *Discovered.* **The demo scale's own hazard**, and that only a grep *outside* the process can see
   a workflow that selects it.
7. *Discovered.* **Site 31.**

### Cost, as the git wall-clock window

| Piece | Window | Bindings (decided / discovered) |
|---|---|---|
| 1 — the PR corpus | **43 min** | 9 (4 / **5**) |
| 2 — the rotating corpus | **16 min** | 7 (5 / **2**) |

**Whole item: 58 minutes** on the clock, handoff `d121aad` to `ee4311c`.

**The discovered count predicts and the total does not, for the FOURTH consecutive measurement.**
Totals of 9 and 7 predict roughly 43 : 33; the measured windows are **43 : 16**. Discovered counts of
5 and 2 give 43 : 17. Cluster 12's refinement to S6's second term survives a fourth data point, and
this is the closest fit yet.

**And a new observation the four data points now support:** piece 1's five discovered bindings were
*all* found by the same activity — **building an instrument and reading its output before trusting
it**. The sweep probe cost perhaps six minutes to write and found sites 28 and 29, the two-key
measurement and the unreachable-by-search finding. **The measurement was cheaper than the deliberation
it replaced**, which is the opposite of how S6's second term is usually paid.

### Round trips

**6 compiler, 2 gate, 4 silent.**

- **Compiler (6).** `std/string as Str` needed explicitly in two modules; `Eq[[int]]` has no instance
  (`a.seeds == b.seeds` needs a hand-written `eq_ints`); a **record update in the head position of a
  cons** does not parse (`{ m | f: [] } :: rest` — `let`-bind it, a new variant of
  `fb_e44ba922db1c42be`'s shape); `${...}` inside a *prose string* is interpolated, so
  `` `gp${draws}-${arg}` `` in an explanatory message is an undefined-variable error; an `Env` read
  needed threading through `generated_world`.
- **Gate (2).** Site 31, and the M2 mutant that turned out to be caught by the wrong check.
- **Silent (4).** Sites 28, 29, 30, 31. **Determinism caught none** — 31 sites, 14 clusters, 0-for-31.

### Judgement ratio, split

(The figure is the *undetermined* fraction.)

- **Machinery, the corpus module: ~65%.** D11 names the two corpora and the three window failure
  modes explicitly and specifies **no shape at all** — not what a member is, not what a key is, not
  what "rotates" means operationally. The determined part is the field list and the failure modes.
- **Content, the fixed bank: ~20%.** The seeds are a query's answer over a 260-seed sweep; what was
  left to judgement is which *five derived selections* form the rule, and that list is the
  interesting artifact. Down from what authorship would have cost, and down for stage 5's reason:
  when the filter is derived and the sweep is wide, the residual lives in one visible place.
- **Machinery, the rotation: ~55%.** D11 gives "changes deterministically and is reported" and
  nothing else. The stride, the space, the wrap, the disjointness, the epoch's source and its
  fail-closed are all undetermined, and the last of those is where the risk actually was.
- **Content, the minimums: ~15%.** Arithmetic over one measured constant; the only judgement is what
  share of a gate a human waits for the PR job may take (5 s of 200 s).
- **Machinery, the CI workflows: ~40%.** The shape is conventional; what is undetermined is the three
  things nothing inside the process can check, which is where the effort went.

---

## An AILANG note

No new defect filed. Two of the three known ones were hit again:

- **`fb_e44ba922db1c42be`** (a call in the field-value position of a record update) has a **sibling in
  the head position of a cons**: `{ m | branches_reached: [] } :: rest` fails to parse with
  `PAT_INVALID_CONS` pointing at the `::`. Same `let`-binding workaround. Worth adding to the
  existing write-up rather than filing separately — it is the same parser confusion about `{`.
- **`fb_b39697480a4e8bbc`** was *not* hit: constructors of an imported type are in scope without being
  named in the import list, which is what let `EpochNotResolved` be used in `corpus_rotating_dst`
  without importing it. That is convenient and it is also how the defect bites in patterns.
- **`fb_2ad074d754cd2c25`** (the flaky cluster harness) did **not** reproduce this cluster;
  `ailang test src/core/dst_corpus.ail` was stable across roughly a dozen runs.

---

## What is NOT done

1. **WI-A17** — correction 0. The `ailang test` coverage axis, groundable now, standalone,
   unassigned since cluster 4. **Milestone A is not complete without it.**
2. **`max_resource_size`** — deferred with reasoning above. **A one-draw item, not a rebinding.**
   Owner: the first item that touches the generator after the corpora exist.
3. **The `ScriptedStep` widenings** — two of them, and cluster 13 separated them: a provider **fault**
   needs an error case, a provider **latency** needs `advance_ms`. Both remain open against D2's
   "response, fault, and latency". Closing the fault half would close **two** register entries at
   once, which is now measurable rather than predicted.
4. **Shrinking** — deferred past the first name-adoption gate, recorded.

---

## A closing view of Milestone A — sixteen items across fourteen clusters

### What the plan got right

**The clustering rule.** "Write the handoff for the next cluster you can ground honestly, and no
further" is the single highest-value process decision in this project. Every handoff cited file:line
anchors that were still valid because the previous cluster had just landed.

**The standing rules, and specifically that they were promoted from execution rather than written in
advance.** S1, S7 and S8 were each earned by a defect and each caught later defects that nothing else
would have. S8's complement — *a pinned artifact certifies exactly the paths its trajectory walks* —
is the most productive sentence in the plan and was written in cluster 12.

**Refusing to size detector work.** S5 says a detector's cost cannot be known before it runs, and
four clusters of measurement never contradicted it.

**Keeping measurements out of versioned artifacts** (cluster 13's D6.4 dividend). It paid again here:
the corpus's observed coverage is not in any versioned artifact, so closing two register entries cost
no version bump.

### What the plan got wrong

**Estimates, in one direction, by orders of magnitude.** A12: "several days" → 92 min. A13 stage 4:
similar. A14: "off by roughly two orders of magnitude". A15: "2–4 days, dominated by CI cost
measurement rather than code" → **58 minutes**, and the CI cost measurement was **76 seconds of it**.
The plan sized artifacts; S6 says count decisions; and after four confirmations the *discovered*
count is the term that predicts.

**The site model does not transfer between kinds of work**, and the plan hedged in the wrong
direction (S4).

**The plan prescribed a fix without measuring the thing it fixed** — the single-key prescription
here, and cluster 13's `max_resource_size` sizing. Both were reasoned from source and both were
wrong in the same way: **a plan can identify a defect correctly and still prescribe a repair for the
wrong direction of it.**

**Spawned items do not acquire clusters.** Correction 0.

### What Milestone B will need that no item report says

**B is externally blocked and its content is known: a repin measured at 381 effect-row edits across
71 files, an extension-ABI major, and the `Message` migration. The person who picks it up will be
cold.** Five things that are true at HEAD and written nowhere in the B items:

1. **The DST gate is now a 4m30s serial cost and B will make it red in bulk.** `make dst` runs 26
   targets at 700 checks. The repin turns effect rows into hard errors *everywhere at once*, so the
   first honest signal after B1 is not a test failure — it is `ailang check` failing in 71 files.
   **Do not run `make dst` until `make check_core` is green**; it will produce thousands of lines of
   downstream noise and cost twenty minutes per attempt.

2. **Three artifacts must be re-pinned by hand and nothing will tell you which.**
   `dst_generator.pinned_canary_v1`/`v2` (6 rows), `seeded_generator_dst`'s seeds 9/13/94 with their
   asserted censuses, and **the twelve corpus seeds in `corpus_pr_dst.fixed_bank()` with their
   asserted reasons**. Each has an *asserted* reason that must survive a re-sweep or be replaced.
   The canary is deliberately un-regenerable — there is no `--update` flag and adding one is
   explicitly refused. **Budget a re-sweep, not a re-pin.**

3. **`live_ports` returning `emissions: []` is load-bearing in four places**, and the recorded-stream
   API landing changes all four at once: D6.4's `StreamDelta` parity gap, `stream_parity_findings`'
   whole trajectory, `provider_partial_stream_then_error`'s register entry, and the corpus's expected
   coverage set. **That is one register entry closing, and closing it is asserted in both directions
   — so B will turn `corpus_pr` red and that is correct behaviour, not a break.**

4. **The `.github/workflows/dst-corpora.yml` scheduled job has never run.** It is written, its entry
   point is checked to exist, its matrix is checked against the declared shard count, and no CI
   scheduler has executed it. The first real scheduled run is an unmeasured event: 240 seeds × 4
   shards against a 600 s budget derived from a **local** 292 ms/seed. **A hosted runner is not a dev
   container**; expect the first run to move `measured_ms_per_seed()` and know that the ceiling gates
   are there to make that visible rather than silent.

5. **The two `ScriptedStep` widenings are the cheapest coverage left in the project and B2 is where
   they become free.** The ABI major already forces a lockstep re-release of every extension package
   and already touches `ExtPorts.ai_step`. Adding the error case and `advance_ms` inside that wave
   costs the anchor cascade *once* instead of twice, and closes two register entries plus D2's
   completeness gap. **Doing them separately after B2 pays the cascade a second time for no reason.**
   Cluster 13 predicted zero A5 anchor cost for the latency field; that prediction is still
   unmeasured and B2 is the item that should measure it.

**And one process observation for whoever picks up B.** Fourteen clusters produced 31 sites where two
answers type-check and the wrong one is silent. **Determinism caught 0 of 31.** Every single one was
found by mutating something and reading *why* a row went red — or, twice now, why one stayed green.
Milestone B is 381 mechanical edits and an ABI major, which is exactly the shape that feels like it
needs no detectors. It is also the shape where a silently-wrong edit is invisible in 71 files of
diff. **Budget mutation loops as the cost of the wave, not as verification after it.**
