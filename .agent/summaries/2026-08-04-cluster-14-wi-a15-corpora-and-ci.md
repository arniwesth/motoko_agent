# 2026-08-04 Cluster 14: WI-A15 — D11's two corpora, their CI jobs, and the coverage swap

## Context

Branch: `arniwesth/mot-53-execute-wi-a15`

Session span: `d121aad` → `43dea57`, **3 commits**, two of them production source. Input was
`HANDOFF-execute-a15-corpora-and-ci.md`, executed cold against HEAD. Fourteenth code session of
project 009, following clusters 1–13.

Re-grounding first, as the handoff instructed: `git diff --stat 3dd8a82..HEAD -- src packages scripts
Makefile` was **empty**, so the handoff's verified-input table held without re-measurement.

**Both mission pieces landed, green and committed.** The `max_resource_size` generator-version bump
the handoff carried was **deferred with reasoning recorded** — the handoff explicitly left that
decision to this session.

| | |
|---|---|
| Piece 1 — the blocking PR corpus | **landed, green** |
| Piece 2 — the scheduled rotating corpus + both CI jobs | **landed, green** |
| The coverage swap (`documented_coverage()` → measured) | **landed, green** |
| `max_resource_size` rebinding | **deferred**, with cluster 13's ground corrected |
| `seed_state` version-axis fix | **not taken**, and not by accident |

## What landed

| Commit | Item | Gate |
|---|---|---|
| `ff54c0f` | **The blocking PR corpus** — twelve derived seeds, a promoted regression, a constructed member; two keys; 20 rejection rules | `make corpus_pr` (new) |
| `ee4311c` | **The scheduled rotating corpus**, both CI jobs, and the coverage swap | `make corpus_rotating` (new) |
| `43dea57` | cluster report, five plan corrections, cluster-map renumbering | note + plan + map |

Three new source files: `src/core/dst_corpus.ail` (1257), `scripts/dst/corpus_pr_dst.ail` (1034),
`scripts/dst/corpus_rotating_dst.ail` (534), plus `.github/workflows/dst-corpora.yml` (129) — the
first workflow in the tree with a generated-trajectory axis. Modified: `Makefile` (+287, two
targets), `scripts/dst/run_report_dst.ail` (the swap). **3927 insertions, 26 deletions.**

**`make dst` exits 0** on the committed tree, read as an exit status — **700 checks** against 591 at
the item's start (670 after piece 1). The single `✗` in the log is the `✗ Failed: 0` summary label of
a passing `ailang test` run, checked rather than assumed. `make check_core` exits 0, **51 modules**
(50 before). A5 anchors verified intact at start and end (`stub_step.ail:161`, `session.ail`
948/1053/2290/2400); `driver_only` stays at **v3** — this item touched none of those files.

## The order the work took

1. **Grounding**, ~20 minutes: cluster 13's note, the plan's standing rules (S1–S8), D11's own text,
   and the export surface of eight DST modules. Baseline `make dst` run for its exit status **and its
   wall clock** (3m19.7s), because D11 delegates seed counts to measured CI cost and the DST gate is
   that measurement's baseline.
2. **A throwaway sweep probe**, written before any corpus code. 260 seeds through the real driver,
   66 s. This is where four of the item's seven discovered bindings came from, and it cost about six
   minutes to write.
3. **`dst_corpus.ail`**, with the rotation's assertions written and run RED against a frozen window
   before `rotating_window` existed (S1).
4. **The PR corpus suite**, then twelve mutation rows and five Makefile-guard mutants.
5. **The rotating suite and the job entry point**, then the four forced failures.
6. **The coverage swap**, last, because it needed the sweep's numbers.

## The decision this item owned, and the handoff's prescription was half right

The handoff and the plan both say: key the corpus on `artifact_identity`, **because** the
`(generator_id, generator_version, seed)` triple aliases under site 22.

Measured at HEAD over 30 adjacent (v2, *s*) / (v1, *s+1*) pairs through the real driver:

| | |
|---|---|
| identical **trajectory** — same interactions, draws, clock, byte length | **29/29** |
| identical **`artifact_identity`** | **0/29** |

**The identities differ because `generator_version` is a field inside the encoded bytes.** Identity
keying cannot merge site 22's aliases — the two artifacts genuinely *are* different bytes. It fixes
the *opposite* direction: two different programs sharing one triple (D4's latency pair), the
direction that **loses** a program. Coverage needs a second key over the interactions alone.

**A plan can identify a defect correctly and still prescribe a repair for the wrong direction of it.**

The demonstration was rebuilt once. The first version copied a member and edited its
`generator_version`, which makes the trajectory keys equal *by construction* — a row asserting a
relationship it had just created. It is now **two real driver runs** compared after the fact.

## `max_resource_size`: deferred, and cluster 13's ground corrected

Cluster 13 assigned it here because "A15 already re-pins seeds and is the cheapest place to absorb a
version bump". Three things say otherwise, and the first is not the cost argument:

1. **It is not unlike D2's other four bounds.** Measured at HEAD, *no* honest bound binds — and that
   is D2's *specified* behaviour, not a defect: exceeding a bound is a generator failure, and
   `make seeded_generator` asserts zero on the honest bounds. `max_interactions` 96 against ≤ 50;
   `max_payload_bytes` 512 against ~15; `max_clock_advance_ms` 2000 against ≤ ~150.
2. **S8's complement is already discharged**, by the artifact stage 5 built for exactly this:
   `canary_bounds_tight` binds every limit for every seed, and the canary folds every *field* of
   every bound failure. The branch is walked and pinned today.
3. **The sizing ground runs backwards.** A15 does not *re-pin* seeds — it *pins new ones from a
   sweep*. A version bump shares no work with that sweep; it **serializes in front of it** and makes
   every swept number provisional.

What is genuinely weak is narrower: the quantity it reports has a **static range of one value**
(`requested` is always 2). **It is a one-draw item, not a rebinding.** Owner: the first item that
touches the generator after the corpora exist — in practice the B wave, which re-sweeps anyway — and
the corpora are now the instrument that makes the new binding measurable.

## Sites 28–31 — four type-checking answers with a silent wrong one

**Thirty-one across fourteen clusters. Determinism has caught none.**

- **Site 28 — the sweep instrument reported that no seed reaches anything.** The probe counted
  interaction kinds with `"provider"`, `"tool"`, `"approval"`; `identity_kind` returns
  `"expect_provider"`, `"expect_tool"`, `"expect_approval"`. Every count was 0 for every seed, and
  the *interaction totals beside them were correct* — which is what makes it survivable, because the
  output looks like data. A bank selected from those rows would have covered nothing while reporting
  twelve members. Caught by reading four rows and asking why a 17-interaction trajectory had no
  interactions of any kind.
- **Site 29 — `fault_class_id` is the right quantity and can only ever name three classes.**
  `ports.tool_outcome_record` is its only writer. Graded by it the sweep reports **0 of 260 seeds
  reach `approval_denied`**, and 152 do. Cluster 13's site 25 one level up. The register would have
  gained two *false* entries, and both would have been believed, because a shrink-only register is
  trusted to be conservative.
- **Site 30 — the alias row asserted a relationship it had just constructed.** Found by writing a
  mutant, watching it **fail to fire**, and reading why.
- **Site 31 — a grep-based guard matched its own comment.** `grep -qE 'MOTOKO_DST_SCALE.*demo'` went
  red on its first run against the workflow comment explaining that the string must not appear. S7:
  anchor a grep guard to a syntactic form. Anchored to a YAML mapping key it stays silent on prose
  and still fires on a real selection — verified both ways.

Two smaller ones of the same shape: the corpus initially carried `elapsed_ms: 1000`, a number the run
never measured; and the sharded job's success line printed the *job's* minimum rather than the
*shard's*.

## What the mutation testing found that the gates did not

Nine mutants, nine caught after the repairs. The instructive one:

| Mutant | Result |
|---|---|
| `all_member_kind_ids()` **drops** a kind | caught — **by the suite, not the Makefile guard** |
| **`all_member_kind_ids()` samples one kind TWICE and omits another** | **suite stayed GREEN; the guard caught it by name** |

**Cluster 13's finding reproduced exactly.** Dropping a kind is caught by the S7 length row, so the
Makefile guard looked redundant. Sampling one twice keeps the length at 3 — only membership-by-name
sees it. The two guards are not redundant; they are sensitive to different things.

## Corrections this session earned

**Correction 0, and it is the one that changes what happens next: A15 is NOT the last item in
Milestone A.** It is the last item on the **critical path** (1 → 6 → 7 → 8 → 9). **WI-A17 is still
open** — spawned by cluster 4, never assigned a cluster, and recorded as unassigned in the cluster
map's own last row for ten clusters, while the plan, three handoffs and this item's commit messages
all carried "the last item in Milestone A". **An item that enters the plan sideways does not acquire
a cluster and nothing in the process notices.** A17 now has cluster number 10, and the rule is
recorded: number a spawned item on the day it is spawned.

Four more, all propagated into the plan:

1. **A corpus needs two keys**, and the plan's prescription fixes the other direction (above).
2. **D11's two counters have two different observers and only one is in-process.**
   `NativeToolDenied` and `NativeToolResults` are both in `d64_gap_register()`, so branch-reached is
   observable *only* on the wire, from production code that knows nothing about the interaction log.
   That is a stronger reason to separate the counters than the one D11 gives.
3. **The bank reaches four of nine required non-waived classes by search; a fifth only by
   construction.** `provider_empty_terminal_response` — 0 of 260 seeds, 0 `empty_stop_finalize`
   records on the wire across the whole sweep. Cluster 12's limit arriving where the plan predicted
   the *shape* and not the *instance* (the plan named the provider fault class).
4. **`documented_coverage()` declared one class Reached that no seed reaches.** True by hand-authored
   scenarios elsewhere, false of every generated program.

## Sizing

**Sixteen recorded bindings — nine decided, seven discovered.**

| Piece | Window | Bindings (decided / discovered) |
|---|---|---|
| 1 — the PR corpus | **43 min** | 9 (4 / **5**) |
| 2 — the rotating corpus | **16 min** | 7 (5 / **2**) |

**Whole item: 58 minutes**, against an estimate of **2–4 days** "dominated by CI cost measurement
rather than code". The CI cost measurement was **76 seconds of it**.

**The discovered count predicts for the fourth consecutive measurement.** Totals of 9 and 7 predict
43 : 33; discovered counts of 5 and 2 give 43 : 17; the measured windows are **43 : 16** — the
closest fit yet.

**A new observation the four data points now support:** piece 1's five discovered bindings were all
found by the same activity — **building an instrument and reading its output before trusting it**.
The sweep probe cost ~6 minutes and produced sites 28 and 29, the two-key measurement, and the
unreachable-by-search finding. **The measurement was cheaper than the deliberation it replaced**,
which is the opposite of how S6's second term is usually paid.

**Round trips: 6 compiler, 2 gate, 4 silent.** Determinism caught none — **0-for-31 across fourteen
clusters**.

**Judgement ratio, split:** corpus module machinery ~65% (D11 names the corpora and the failure modes
and specifies no shape at all); fixed bank content ~20% (a query's answer over 260 seeds); rotation
machinery ~55%; the minimums ~15% (arithmetic over one measured constant); CI workflows ~40%.

## AILANG notes

No new defect filed. One known defect gained a **sibling worth appending to its write-up**:
`fb_e44ba922db1c42be` (a call in the field-value position of a record update) also bites in the
**head position of a cons** — `{ m | branches_reached: [] } :: rest` fails with `PAT_INVALID_CONS`
pointing at the `::`. Same `let`-binding workaround, same parser confusion about `{`.

`fb_2ad074d754cd2c25` (the flaky cluster harness) did **not** reproduce; `ailang test
src/core/dst_corpus.ail` was stable across roughly a dozen runs.

New compiler friction worth knowing: `${...}` inside a **prose string** is interpolated, so
`` `gp${draws}-${arg}` `` in an explanatory message is an undefined-variable error; and `[int]` has
no `Eq` instance, so list equality needs a hand-written `eq_ints`.

## State at session end

- **`make dst` exit 0, 700 checks. `make check_core` exit 0, 51 modules.** Working tree clean.
- **Milestone A is one item short: WI-A17**, groundable now, standalone, parallelisable, small.
- Milestones B and C remain externally blocked on the upstream recorded-stream API.
- The full report, including a closing view of Milestone A and **five things Milestone B will need
  that no item report states**, is
  `.agent/projects/009_motoko_dst_execution/NOTE-cluster-14-execution-report-and-plan-corrections.md`.

**The single most useful thing carried forward for whoever picks up B:** fourteen clusters produced
31 sites where two answers type-check and the wrong one is silent, and determinism caught 0 of 31.
Milestone B is 381 mechanical edits and an ABI major — exactly the shape that feels like it needs no
detectors, and exactly the shape where a silently-wrong edit is invisible in 71 files of diff.
Budget mutation loops as the cost of the wave, not as verification after it.
