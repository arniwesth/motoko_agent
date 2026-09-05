# 2026-08-03 Cluster 2: WI-A4, A5, A11 — three detectors, and the first calibration on detector work

## Context

Branch: `arniwesth/mot-49-execute-wi-a4-wi-a5-wi-a11`

Session span: `be748de` → `07904e8`, **6 commits**, three of them production source. Input was
`HANDOFF-execute-a4-a5-a11-detectors.md`, executed cold against HEAD. Fifth code session of project
009, following cluster 1, cluster 4, cluster 6 and cluster 3.

**This was the last unstarted independent work in Milestone A.** A10 was blocked on this cluster
alone, and A10 blocks A13, A14 and A15 — so everything remaining sat behind it. It is now unblocked.

The three items are grouped by *shape*: a program that inspects the tree and fails closed, plus a
test suite that proves it can fail. That shape is a third kind, after widen-and-converge (clusters
1, 4, 6) and constructed artifacts (cluster 3), and it turned out to need its own sizing model.

Re-grounding first: `git diff --stat 0615637..HEAD -- src packages scripts Makefile` was empty, so
the handoff's anchor table held without re-measurement — and every count in it reproduced exactly.

## What landed

| Commit | Item | Detector + gate |
|---|---|---|
| `5ad3433` | **WI-A4** | `tools/ext_call_inventory/derive.py`, `make ext_call_inventory` + `_selftest` |
| `24ed3ea` | **WI-A5** | `src/core/dst_attribution_table.ail`, `make attribution_table` |
| `08b7a75` | **WI-A11** | `tools/predicate-anchors/check.py`, `make predicate_anchors` |
| `c29ea04` | report | costs, ratios, five ADR amendments |
| `86a46e6` | propagation | P3 corrected, S5 promoted, A10's two decisions, iface defect filed |
| `07904e8` | handoff | cluster 5 — WI-A10 |

All four new targets are in `make dst` and in CI. The aggregate
(`profile_coverage fault_catalogue event_vocabulary attribution_table predicate_anchors
ext_call_inventory ext_call_inventory_selftest`) exits 0.

**No existing `.ail` source was modified.** The whole cluster is new files plus Makefile, CI and
docs — which is itself a useful fact about detector work: it observes the tree rather than changing
it, so the usual convergence-wave risk is absent.

## The finding the handoff sent me to make, and the tool made it independently

The handoff's central instruction was to build classifier 2 against D5's **criterion**, not D5's
**list**, because WI-A12 had falsified the list three commits earlier. The classifier does exactly
that — it re-reads the `ExtPorts` record, the core `Ports` record and the `session.ext_ports_of`
bridge on every run — and **reached the corrected set on its own**, without being told the answer:

| Field | Fronts | Seam threads | Ext can return | Verdict |
|---|---|---|---|---|
| `ai_step` | `Ports.model_step` | `ProviderExchange.next_state` | no | **member** |
| `proc_exec` | `Ports.tool_exec` | `ToolExecution.next_state` | no | **member** |
| `env_get` | `Ports.env_get` | `EnvRead.next_state` | no | **member** |
| `clock_now` | — | n/a | n/a | **unrouted** |

Nothing distinguishes a discarded `ToolExecution.next_state` from a discarded
`ProviderExchange.next_state`, so the criterion selects three.

**It also corrected the handoff's own reasoning.** D5 excludes `clock_now` on the ground that it
"loses no cursor". `Ports.clock_now` returns a `ClockReading` carrying `next_state`, so there *is* a
cursor to lose; the correct ground is that the extension seam never reaches that port at all —
`ext_unrouted_clock` performs an ambient `now()`. That is a **worse** condition than membership, not
a better one, and it is deliberate under plan rule S2 with the `Clock` poison probe as its
instrument. Recording it as a distinct third state (`unrouted`) rather than folding it into
non-member is what keeps the two from being confused.

**Exposure was checked before amending, because a scope change would have been the plan's call.**
Zero calls to `proc_exec`, `env_get` or `clock_now` outside the ABI package; all fourteen
configurations install `compaction_ai`, which already calls `ai_step`. No configuration moves — a
wording correction, not a scope change.

## Detector work needs a third sizing model, and it was promoted to S5

S4 prices artifact rows by whether their content must be *discovered* or *transcribed*. Neither
applies to a program. But the interesting fact is not that the unit differs — it is *why* both
existing models fail:

**A widen-and-converge site and an artifact row are both countable from the source in advance. A
detector's cost is dominated by defects in the detector itself, which are invisible until it runs
against real source.** Nothing told me in advance that `func_body` would grab an effect row instead
of a function body.

| | Round trips to green | Time | Nature |
|---|---|---|---|
| **A4** | **4** | ~11 min | each produced a *plausible report* to be read and disbelieved |
| **A5** | **4** | ~8.5 min | all four were compiler errors with line numbers |
| **A11** | **1** | ~5.5 min | not a code defect — the ADR's "six" had no enumeration |

Round trips predict the times far better than lines or files do, and **the weighting matters more
than the count**: budget loud defects at near-zero and silent ones at the cost of noticing them.
Promoted to the plan as **S5** in `86a46e6`.

## Judgement ratio: high, not low — which falsifies the handoff's own prediction

The handoff predicted A4 might come in low like A6 (16%) because classifier 1 is a working
precedent. It came in at **58%**. A5 at 29%, A11 at 100%.

Classifier 1 supplied the *shape* and none of the *content* — fail-closed posture, the `/tmp`
refusal, the `make` target + selftest pair, JSON output, exit-code convention, and the habit of
encoding each trap where it matters. All adopted verbatim, and that is why A4 took 11 minutes rather
than the estimated afternoon. But classifier 1's membership input is **a single JSON field**;
classifier 2's is a **three-source cross-record derivation** for which it has no analogue.

**The corrected predictor is confirmed by its logic rather than by its number.** It says judgement
tracks how much the specification leaves undetermined. A6 was 16% because D5's rules were stated and
correct. A4 was 58% because D5's rules were stated and **wrong**. A11 is 100% because classifying
each passage is a judgement by construction — which is why that artifact records a named reviewer
per passage rather than a rule.

## Five sites admitted two answers with a silent wrong one, and four failed open

For a detector the characteristic form is **a matcher that passes while failing open**.

1. **`func_body` returning the effect row instead of the body.** An AILANG signature ends
   `-> T ! {IO, Clock} {`, so the first `{` after a header is the effect row. Taking it yields a
   fragment in which no seam is ever found — so **every field classified `unrouted` and the
   classifier-2 set came back empty**. No exception, no warning: a clean-looking clean audit, which
   is exactly what a fail-open detector produces. It recurred in `let_lambda_body`, which is why
   `body_after` is now one function used by both.
2. **`binder_types` reading record literals as annotations.** `PortedProvider` binds `ports: p`, so a
   flat `name: Type` scan concluded `ports` has type `p`. Failed **loudly** — eight unresolved
   entries naming the driver's own calls — and is kept in the record as the contrast: same class of
   slip, opposite direction, an order of magnitude cheaper to find.
3. **The name-based carrier rule.** `recv.endswith(".ports")` counted `provider.ports.clock_now` as
   an extension seam when `provider` is a `PortedProvider` whose `.ports` is the *core* `Ports`.
   Silent, in the over-counting direction. Fixed by making carrier resolution purely type-based.
4. **A5's `hook_id_matches` — the sharpest of the five.** Rows name base hook ids; `parse_tokens`
   stamps installed hooks `name#idx`. Under plain equality a row's `scratchpad` intersects
   **nothing**, the intersection is empty, and the empty-intersection rule then declares the site
   *genuinely unreachable* and drops it — **the exact inverse of what the attribution says, with no
   error and no failing test** unless a test uses a suffixed id. D4's own fail-open shape re-entering
   through the matching function instead of through the rule.
5. **The meta-instance: membership from D5's list rather than its criterion** — the same defect one
   level up, and why the classifier never consults a list, including the one in its own self-test.

Determinism would have caught none of them. What caught them: running against real source and reading
the output (1, 3), writing the test with a suffixed id (4), and the handoff (5).

## Five ADR amendments

All filed as amendments, not review rounds — the ADR is Accepted. Detail in
`NOTE-cluster-2-execution-report-and-plan-corrections.md`.

- **C1 (A4).** D5's classifier-2 non-member list is stale: three members, `clock_now` excluded on the
  corrected ground.
- **C2 (A5).** D4's mixed-guard anchor moved — `tool_phase.ail:222` → guard `:286`, call `:287`. The
  example survived; its coordinates did not.
- **C3 (A5).** D4's "four driver clock sites" is now **five routed plus two ambient**. The `4/12/13`
  and `5/13/13` splits describe a tree A12 has changed.
- **C4 (A5).** Clause 1's fallback is silent on whether an unattributed core site is *routed*.
  `session.ail:796` is core, unattributed and deliberately unrouted; a profile folding it into "the
  unconditional set, all routed" asserts something false.
- **C5 (A11).** D1's "six normative sites" was a count with **no enumeration**, which makes A11's
  "outside the six" clause unenforceable. Two defensible sixes existed. D1 now enumerates them.

Plan: P3 corrected in `86a46e6` — and the correction is **to stop citing a number**, since C3 is the
second time inside one milestone that a transcribed count went stale. A5 already discharges it the
right way: the completeness check takes the discovered set as an **argument**, never a constant.

**Upstream:** a fourth `ailang iface` defect filed to `fb_d230853828108783` — `iface` fails `MOD010`
on this repo's packages given an **absolute** path and succeeds given a **relative** one, the
opposite of classifier 1's `std/` experience, and the error's two suggested fixes
(`--relax-modules`, `AILANG_RELAX_MODULES=1`) are **both rejected by `iface` itself** while `check`
honours the env var.

## Standing rules

**S1 held, and its completeness half did the work in all three items.** A4's acceptance is the
fixture suite, not the HEAD run — and **all five fixtures type-check**, so the unresolvable forms are
real AILANG an extension could write today rather than illustrations. A5's set-completeness fixture
is what separates the validator from a row-shape validator, and the DST script asserts it fires
**alone**. A11's two halves are both required, and the *green* one is the falsifiable half.

Each detector also carries a **negative control on itself** — a fixture that must come back clean, a
`validate_at_load` that must accept, a passage set that must match — because a detector that only
ever fires passes a suite of only-failing fixtures while being useless.

**S2 was load-bearing in A4's design** — it is why `unrouted` is a distinct membership state.

**S3 did not apply**; no seam ordering in this cluster.

**S4 does not transfer**, and **S5** was promoted in its place.

## Tooling

The parallel `ailang check` closure tool was **not** rebuilt or used. Detector work produces no
convergence wave — no existing `.ail` source changed — so the tool has nothing to parallelise here.
Cluster 3 already suspected it matters less outside widen-and-converge; this is a second data point,
and A13/A14 should re-test rather than assume.

Three AILANG pin frictions worth carrying forward, all in A5: `++` is list-only (strings need
`"${}"` interpolation or `concat`/`join`); a nested string with escapes inside `${...}` does not
parse; `show` on a bool needs a helper. All four of A5's round trips were one of these.

## Handoff notes for cluster 5 (WI-A10)

Written up in `HANDOFF-execute-a10-profile-and-manifest.md` (`07904e8`) with every cited export
verified to exist. The load-bearing ones:

- `dst_attribution_table.validate_at_load(loading_against, discovered)` — the whole load-time gate in
  one call.
- `table_identity()` — the `(source revision, content hash)` pair a profile records. **A table
  correction re-issues every referring profile**, as D4 states.
- `reachable_core_sites(installed)` — unconditional core plus attributed-and-intersecting.
- `make ext_call_inventory --json` — `classifier_2_set`, `unrouted_fields`, `member_call_sites`,
  `unresolved`, plus per-field membership rationale for the manifest's derived-set records.

Two decisions this cluster deliberately did **not** make, both now A10's:

1. **Whether a profile with an unrouted reachable core site is conformant.** Two exist
   (`session.ail:796`, `stub_step.ail:146`), both declared with `routed: false`. D4's all-or-nothing
   rule points at non-conformant; whether `stub_step.ail:146` is even in a deterministic profile's
   reachable set is the live question, since `live_ports` is not the adapter a deterministic run uses.
2. **`driver_only`'s routed-set claim**, left alone per the handoff. The table it needs now exists —
   and per P3's correction it should be stated by derivation rather than as a number.

The interprocedural attribution-necessity validator remains **unbuilt and unscheduled**, per D4.
Row 2's necessity rests on its named reviewer and the module says so.
