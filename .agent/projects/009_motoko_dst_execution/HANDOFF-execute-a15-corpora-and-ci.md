# Handoff: execute WI-A15 — D11's two corpora and their CI jobs

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**Cluster 9.** ~~The last item in Milestone A~~ — **wrong, and corrected by cluster 14's correction 0
after this handoff was consumed.** A15 is the last item on the **critical path**; **WI-A17** is off
it, was spawned by cluster 4 rather than planned, never acquired a cluster, and is the actual last
item in Milestone A. The sentence was inherited across three handoffs and the plan, none of which
re-read the cluster map's own last row. WI-A14 landed 2026-08-04 (`00dbdb4`, `ea81e66`,
`3dd8a82`); `make dst` is exit 0. Every dependency is in. **When this lands, Milestone A is complete**
and the project is externally blocked on the upstream recorded-stream API for Milestones B and C.

**Read first:** `NOTE-cluster-13-execution-report-and-plan-corrections.md` — its closing *"What A15
should carry"* is addressed to you — then the plan's `## Standing rules`. **S7 and S8 are the whole
risk here**, and S8 in a form this item is uniquely exposed to.

## Mission

D11's two corpora and their CI jobs, in **two commits** — the corpora are independent of each other
and cluster 13 measured that grounding is paid per *session*, so taking both here is right, but each
should end green on its own:

1. **The blocking PR corpus** — fixed seeds plus exact promoted regression programs.
2. **The scheduled rotating corpus** — a seed window that changes deterministically and is reported.

Plus, for both: rotation, retention, sharding and each job's **operator-accepted minimum seed
count**, all *selected from measured CI cost* rather than chosen — D11 delegates that to this plan by
name, so measuring is part of the work.

## The rule you will break by accident

**A window that does not rotate is *more* deterministic, not less — and determinism is the only
property a rotating corpus obviously has.**

D11 asks for a seed window that *"changes deterministically and is reported"*. That is **two**
properties, and the failure is that a window ignoring its input satisfies the first perfectly:

- same seeds every scheduled run → **perfectly deterministic**, byte-identical reports;
- every existing gate green, because nothing in the tree asserts that a window *moves*;
- and the corpus searches exactly one neighbourhood forever while reporting that it rotates.

**Determinism is 0-for-27 across thirteen clusters** and this is the shape it fails on again: a frozen
thing is perfectly reproducible. It is site 21's defect one level up — stage 4's generator read its
seed only to print it and passed a sensitivity axis — and S8 is the rule: **check that the window's
input cannot reach the reported seeds except through the rotation.** Per S8's complement, also check
that the rotation's *branches* are entered: a window that rotates only across a boundary the test
period never crosses is unpinned, and unpinned reads identically to unchanged.

**Its companion, and D11 states it outright:** *"A zero, silently truncated, or below-minimum window
fails."* A gate that asserts "no failures" is green on a window that ran **zero seeds** — zero
failures out of zero runs. D11 requires the gate to assert **the exact declared count completed**,
not that nothing broke. Write the count assertion before the job, per S1.

## The decision this item owns

**Site 22's residue: the version axis is decorative, and a corpus is where that stops being harmless.**

`seed_state` is `in_range(salt_hash("${id}/${version}") + seed)` — version hash and seed are **added**,
so interchangeable — hence version `"2"` at seed *s* is byte-identical to version `"1"` at seed
*s+1*, measured across all 259 adjacent pairs. A corpus holding (v1, seed 4) and (v2, seed 3)
**has one program's worth of coverage while reporting two.**

A13 stage 6 decided to key the *store* around this rather than fix it, on a ground that was not the
cost argument: the triple omits the manifest, so `(id, version, seed)` was never a key regardless.
That decision was right for a store. **For a corpus it is only half an answer**, because a corpus
makes a *coverage claim*, and aliasing inflates it.

So: **key and deduplicate on `artifact_identity`** (`dst_persistence.ail:1016`, sha256 of the exact
bytes — the only thing in that module described as unique). Cluster 13 handed you the worked example:
D4's latency pair produces two identities (`2095b6d8…`, `70605bfb…`) from worlds differing in one
integer, and a corpus keyed on the triple would have filed them as one, since they differ in neither
version nor seed.

**And decide, with reasoning recorded, whether the rebinding below is taken here or deferred again.**

## The generator-version bump this item carries

**`max_resource_size` is A15's, and it is a generator-version item, not a field edit** (cluster 13,
decision 3). It is bound to the synthetic environment's entry count and measures nothing in a real
run. Deleting it is **wrong on the merits** — D2 requires five declared bounds and dropping the
fourth makes the set 4 of 5, a specification regression wearing a cleanup's clothes — *and* costs a
schema version, since `bounds` encodes as a five-field line with `required_header_tags()` declaring
arity 5 and both frozen specimens carrying it.

So keep the bound and **rebind it to a resource that grows.** That changes when
`choose_environment`'s bounded alternative is taken, which changes the draw stream — which is exactly
what D8 requires a generator-version bump for and what stage 5's canary exists to catch. **Re-pinning
`pinned_canary_v1`/`v2` and re-sweeping stage 4's seeds 9, 13 and 94 is part of the work, not an
afterthought**, and each of those seeds has an *asserted* reason that must survive the re-sweep or be
replaced by one.

## Inputs, verified at HEAD

**Run `git diff --stat <last-good>..HEAD -- src packages scripts Makefile` first; if non-empty,
re-verify.**

| Input | Where |
|---|---|
| The run report — `RunReport`, `validate_report`, `report_ok`, `render_report`, `ReachStatus` (four not-reached variants + a waiver) | `dst_run_report.ail:126-761` |
| **`documented_coverage()` — a DECLARED register, labelled as such in the rendered output** | `scripts/dst/run_report_dst.ail:238` |
| The CI replay affordance — `replay_entry_point()`, `replay_command`, `replay_line` | `dst_run_report.ail:377-383` |
| Persistence — `artifact_identity` (`:1016`), `persist_program` (`:1059`), `load_program` (`:1099`) | `dst_persistence.ail` |
| The catalogue — `required_class_ids()`, `conditional_class_ids`, `waiving_condition` | `dst_fault_catalogue.ail:165, 500, 511` |
| The generator, its bounds, `canary_row_from` (`:995`), the pinned tables | `dst_generator.ail` |
| Replay — strict and regression, `regression_report` | `dst_replay.ail` |
| The invariants — twelve families, `d64_gap_register()`, `parity_gap_reasons()` | `dst_invariants.ail` |
| `driver_only()` v3 and its manifest | `dst_driver_only.ail` |

## Definition of done

**Both jobs run and declare their minimums**, and the gate **fails** on a zero, silently truncated, or
below-minimum window — demonstrated by forcing each of the three, not asserted.

**The rotating window is shown to rotate**, per the rule above, with the input's route to the reported
seeds shown to run only through the rotation.

**The fixed bank collectively reaches every required non-waived fault class** (`required_class_ids()`),
and every waiver is declared with its condition per D3. **This is the swap that matters:**
`documented_coverage()` is a *declared* register, and A15 replaces it with **observations from a real
sweep** — the moment the three unreached classes stop being documented and start being measured. Keep
the declared register as the thing the observations are checked against, and per cluster 13 make it
**shrink-only**: assert the declared set equal to the observed set in **both** directions so an entry
can only close, and closing one is forced to be recorded. That pattern is now used twice
(`d64_gap_register()`, `documented_coverage()`) and this is its third.

**A promoted failure travels as one artifact** — the exact program **with** its execution manifest.
D8's reproducibility promise is conditioned on the manifest, so a program promoted without one is not
a reproduction unit. A corpus member whose manifest is stale or unresolvable is **not silently
reinterpreted**: strict replay fails closed, regression replay may proceed only with the difference
recorded.

**Select by sweep-and-filter, with cluster 12's limit applied.** State the corpus obligations as a
filter, sweep, pin the survivors, and prefer among them on the one axis the filter cannot express.
**But sweeping selects among things that exist and cannot cover a space the producer does not
reach** — where the generator cannot produce a shape (the provider fault class; see below), construct
against a derived requirement instead.

**Per S7, asserted executably:** any surviving fixture carries every shape the specification protects,
with **no two of its quantities equal**. **Every structural guard mutation-tested**, each row
asserting **its own rule** — cluster 13's site 26 is the fourth time that has paid, and cluster 12's
nullary-constructor guard is why a *count* is not enough. Any new grep-based Makefile guard
**anchored to a syntactic form**.

## Out of scope

- **The `ScriptedStep` widenings.** Two separate ones, and cluster 13 separated them: a provider
  **fault** needs an error case, a provider **latency** needs `advance_ms`. Neither is D4's — the
  latency pair is built on the tool class and is done. Both remain open against D2's "response,
  fault, and latency" and belong with the generator's completeness, not here. Predicted zero A5
  anchor cost, unmeasured.
- **`routing_violation_at`'s call site** — WI-C5's, structurally.
- **Fixing `seed_state`** — decide whether the `max_resource_size` rebinding is the moment to also
  fix the version axis, or keep them separate; do not do it by accident.
- **Shrinking** — deferred past the first name-adoption gate, recorded.
- **Everything in Milestones B and C.** The upstream recorded-stream API has not shipped in a
  released AILANG; the repin and the name gate are externally blocked and nothing here moves them.

## Stop and report rather than deciding inline

- **If measured CI cost makes the declared minimums unaffordable**, report the measurement and the
  trade rather than quietly lowering the count — D11 makes the minimum operator-accepted, which means
  it is a decision with an owner, not a tuning parameter.
- **If the fixed bank cannot reach a required non-waived class**, that is a coverage finding, not a
  reason to waive it. D3 requires a waiver to name its condition, and three of the currently-unreached
  classes are unreached in three *different* ways that must not be merged.
- If the `max_resource_size` rebinding turns out to move more than the canary and three seeds, stop
  and report the blast radius before proceeding.

## Traps

**Run `make dst` and read `$?`** — sixth consecutive item where this mattered. **Do not run other
`make` targets concurrently with it.** The single `✗` in a green log is the `✗ Failed: 0` summary
label of a passing `ailang test` run.

**A5 anchors: `stub_step.ail:161`, `session.ail`'s 948/1053/2290/2400; `driver_only` is v3.** Five
data points now say the cascade correlates with adding a **`StepProvider` variant**, not with editing
near an anchor — A14 edited *above* two anchors and paid nothing by keeping the edit line-count
neutral. The coordinate-independent anchor is decided **not to build**; revisit only if you must add
a variant.

**Three filed AILANG defects will shape this item's code**, all with workarounds:
`fb_e44ba922db1c42be` — a call in the field-value position of a record update is not a dependency;
`let`-bind it (hit at ten sites in one cluster-13 script, the most frequently-hit of the three).
`fb_b39697480a4e8bbc` — an out-of-scope constructor name in a pattern binds as a fresh variable.
`fb_2ad074d754cd2c25` — `ailang test`'s cluster harness fails non-deterministically at ~6/10 in large
modules; if a gate goes flaky, move the assertion into an acceptance script under `ailang run` rather
than re-running. All three are written up in `.agent/issues/`.

Clear `.ailang/cache` before believing a contradicting type error. Never probe from `/tmp`. Pin is
v0.26.0.

## Report back

Fourteenth calibration run, and **the last of Milestone A** — so the report should close the
milestone as well as the item.

- **The git wall-clock window**, not a felt ratio. Cluster 13's pieces were 56 / 12 / 10 minutes
  against binding totals that predicted 56 : 48 : 32, and the **discovered** count ordered them
  correctly for the third consecutive measurement.
- **Recorded bindings, split decided versus discovered, per commit.**
- **Judgement ratio, split** machinery versus content.
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** Twenty-seven across thirteen clusters; determinism has caught none.
- **A closing view of Milestone A**: eighteen work items across fourteen clusters, what the plan got
  right and wrong, and — most usefully — **what Milestone B will need that no item report says.**
  B is externally blocked but its content is known: a repin measured at 381 effect-row edits across
  71 files, an extension-ABI major, and the `Message` migration. The person who picks that up will be
  cold.
