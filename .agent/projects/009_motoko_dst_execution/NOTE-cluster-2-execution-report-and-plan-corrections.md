# Cluster 2 execution report — WI-A4, WI-A5, WI-A11, and five ADR amendments

Executed 2026-08-03 against HEAD `be748de`. `git diff 0615637..HEAD -- src packages scripts
Makefile` was empty, so the handoff's anchor table held without re-measurement — and every one of
its counts reproduced exactly.

Three commits, three detectors:

| | Commit | Lines | Files | Build time |
|---|---|---|---|---|
| WI-A4 classifier 2 | `5ad3433` | 908 | 12 (8 new) | ~11 min |
| WI-A5 attribution table | `24ed3ea` | 1030 | 6 (2 new) | ~8.5 min |
| WI-A11 predicate anchors | `08b7a75` | 400 | 6 (3 new) | ~5.5 min |

`make --keep-going profile_coverage fault_catalogue event_vocabulary attribution_table
predicate_anchors ext_call_inventory ext_call_inventory_selftest` exits 0. All three new targets are
in `make dst` and in CI.

Definition of done, all three met: classifier 2 reports the two known `ai_step` sites and **zero
unresolved** at HEAD, with a fixture per unresolvable form reported as unresolved; A5's validation
rejects unknown hook ids, stale bindings and malformed rows, permits known-but-uninstalled, exercises
the empty-intersection rule in both directions, and **rejects a discovered site present in neither
list**; A11 is green on the unmutated ADR and red on a mutated anchor.

## Detector work needs a third sizing model, and the distinguishing property is that it cannot be sized before it runs

S4 prices constructed-artifact rows by whether their content must be **discovered** or
**transcribed**. Neither applies here, and the handoff was right to ask. But the interesting fact is
not that a program is a different unit — it is *why* the two existing models both fail:

**A widen-and-converge site and an artifact row are both countable before you start. A detector's
cost is dominated by defects in the detector itself, and those are invisible until it runs against
real source.** A7's 68 rows and A8's 158 were countable from the source in advance. Nothing told me
in advance that `func_body` would grab an effect row instead of a function body.

So the third model: **price a detector by its defect-discovery round trips** — run, get a wrong
answer, locate the cause, fix — plus a flat cost for the shape the precedent supplies.

| | Round trips to green | Cause of each |
|---|---|---|
| **A4** | **4** | effect row parsed as function body; record literals parsed as type annotations; name-based carrier rule; lambda signature effect row (the first defect, recurring in a second function) |
| **A5** | **4** | all four were the AILANG pin's string handling, not logic: `++` is list-only, nested escapes inside `${}`, `show` on bool, one stray-byte edit |
| **A11** | **1** | not a code defect at all — the ADR's "six" had no enumeration to check against |

The round-trip counts predict the build times far better than lines or files do: 11 / 8.5 / 5.5
minutes against 4 / 4 / 1 round trips, and A5's four were cheap mechanical ones while A4's four each
needed the output read and a cause located.

**A4's per-round-trip cost was higher because its wrong answers looked right.** Three of A4's four
defects produced a *plausible* report rather than a crash — see below. A5's four produced compiler
errors with line numbers. That is the real cost driver, and it argues for the model: not "how many
round trips" alone but "how many of them fail loudly."

## Judgement ratio: high, not low — and this falsifies the handoff's own prediction

The handoff predicted A4 might come in low like A6 did (16%, rules fixed verbatim) because
classifier 1 is a working precedent. **It did not, and the reason is worth recording because it
generalises.**

Classifier 1 supplied the *shape* and none of the *content*: fail-closed posture, the `/tmp`
refusal, the `make` target plus selftest pair, JSON output, the exit-code convention, and the habit
of encoding each trap at the point it matters. All adopted verbatim — that is real and it is why A4
took 11 minutes rather than an afternoon as estimated.

But classifier 1's membership input is **a single JSON field** (`effects`, with `pure` ignored).
Classifier 2's membership is a **three-source cross-record derivation** — the `ExtPorts` record, the
`Ports` record, and the bridge between them resolved through closures and named wrappers — for which
classifier 1 has no analogue at all. Counting decisions that could have gone the other way:

| Area | Decisions | Judgement | Fixed by precedent |
|---|---|---|---|
| Membership derivation | 7 | 7 | 0 |
| Receiver typing / resolvability | 9 | 6 | 3 |
| Tool shape, wiring, output | 11 | 1 | 10 |
| Fixtures | 6 | 5 | 1 |
| **A4 total** | **33** | **19 (58%)** | 14 |
| **A5 total** | **41** | **12 (29%)** | 29 |
| **A11 total** | **13 passages** | **13 (100%)** | 0 |

**The corrected predictor is confirmed, but by its own logic rather than by its number.** The
predictor says judgement tracks how much the specification leaves undetermined. A6 came in at 16%
because D5's rules were stated and correct. A4 came in at 58% because D5's rules were stated and
**wrong** — the item whose specification most needed re-derivation had the highest ratio, which is
what the predictor claims. A11 is 100% because the classification of every passage is a judgement
by construction; that is why the artifact records a named reviewer per passage rather than a rule.

## Sites where both answers type-check and the wrong one is silent

For a detector the characteristic form is **a matcher that passes while failing open**. Five, and
the first is the one the handoff predicted:

**1. `func_body` returning the effect row instead of the function body.** An AILANG signature ends
`-> T ! {IO, Clock} {`, so the first `{` after a function header is the effect row. Taking it yields
the fragment `AI, IO, Process, ...`, in which no seam is ever found, so **every `ExtPorts` field
classified as unrouted and the classifier-2 set came back empty**. No exception, no warning, a
clean-looking report — and a clean report is exactly what a fail-open detector produces. It then
recurred in `let_lambda_body`, which is why `body_after` is one function used by both.

**2. `binder_types` reading record literals as type annotations.** `PortedProvider`'s construction
binds `ports: p`, and a flat `name: Type` scan concludes `ports` has type `p`. This one failed
**loudly** — eight unresolved entries naming the driver's own calls — and is recorded here as the
contrast: same class of parsing slip, opposite failure direction, ten times cheaper to find.

**3. The name-based carrier rule.** `recv.endswith(".ports")` resolved `provider.ports.clock_now` as
an extension seam when `provider` is a `PortedProvider` whose `.ports` is the *core* `Ports`. Wrong
in the over-counting direction, and silent: the report simply listed two core driver sites as
extension calls. Fixed by making carrier resolution purely type-based.

**4. A5's `hook_id_matches`, and this is the sharpest of the five.** Rows name base hook ids;
`parse_tokens` stamps installed hooks as `name#idx`. Under plain string equality a row's
`scratchpad` intersects **nothing**, the intersection is empty, and the empty-intersection rule then
declares the site *genuinely unreachable* and drops it from the profile — **the exact inverse of what
the attribution says, arrived at with no error and no failing test** unless a test uses a suffixed
id. D4's own fail-open shape re-entering through the matching function instead of through the rule.

**5. The meta-instance: membership from D5's list rather than from D5's criterion.** This is the same
defect one level up, and it is why the classifier derives membership on every run and never consults
a list — including the one in its own self-test, which is a regression guard the tool does not read.

Determinism would have caught none of the five. What caught them: for 1 and 3, running against real
source and reading the output; for 4, writing the test with a suffixed id; for 5, the handoff.

## The D5 finding, verified from source and derived independently by the tool

The handoff's central instruction was to build against the criterion, not the list. Confirmed at
HEAD, and **the classifier reached the corrected set on its own** from the `ExtPorts` record, the
`Ports` record and `session.ext_ports_of`:

| Field | Fronts | Seam threads | Ext can return | Verdict |
|---|---|---|---|---|
| `ai_step` | `Ports.model_step` | `ProviderExchange.next_state` | no | **member** |
| `proc_exec` | `Ports.tool_exec` | `ToolExecution.next_state` | no | **member** |
| `env_get` | `Ports.env_get` | `EnvRead.next_state` | no | **member** |
| `clock_now` | — | n/a | n/a | **unrouted** |

Nothing distinguishes a discarded `ToolExecution.next_state` from a discarded
`ProviderExchange.next_state`, so the criterion selects three.

**`clock_now`'s exclusion is right and D5's stated reason for it is wrong.** D5 says it "loses no
cursor"; `Ports.clock_now` returns a `ClockReading` carrying `next_state`, so there is a cursor to
lose. The correct ground is that the ext seam never reaches that port — `ext_unrouted_clock` performs
an ambient `now()` — so the criterion's first conjunct is unsatisfied. That is a *worse* condition
than membership, and it is deliberate under plan rule S2, with the Clock poison probe as its
instrument. Recording it as a third state (`unrouted`) rather than as a non-member is what keeps the
two from being confused.

**Exposure checked before amending, because a scope change would have been the plan's call to make.**
Zero calls to `proc_exec`, `env_get` or `clock_now` outside the ABI package; all fourteen
configurations install `compaction_ai`, which already calls `ai_step`. No configuration moves. A
wording correction, not a scope change.

## Plan and ADR corrections

Five ADR amendments, all filed as amendments rather than review rounds (the ADR is Accepted).

**C1. D5's classifier-2 non-member list is stale (A4).** Three members, not one; `clock_now` excluded
on the corrected ground. Amendment reports the derived table and states that the table is the tool's
*output*, not its input.

**C2. D4's mixed-guard anchor moved (A5).** `tool_phase.ail:222` → the guard is `:286` and the call
it guards is `:287`. The example survived; its coordinates did not. `make attribution_table` now
re-checks every cited line's **content** on each run.

**C3. D4's core clock inventory is no longer four driver sites (A5).** At HEAD: **five** routed core
sites (A12 added `tool_phase.ail:342`) and **two** ambient ones that did not exist when the table was
written (`session.ail:796` under S2, `stub_step.ail:146` in `live_ports`). The `4 / 12 / 13` and
`5 / 13 / 13` splits describe a source tree A12 has since changed.

*The design consequence is already discharged:* the completeness check takes the discovered set as an
**argument**, never as a constant. A validator holding its own copy of "the thirteen sites" agrees
with itself by construction and goes stale exactly when the source moves — which happened twice
inside one milestone.

**C4. Clause 1's fallback is silent on whether an unattributed core site is ROUTED (A5).**
`session.ail:796` is core, unattributed and deliberately unrouted. A profile folding it into "the
unconditional set, all routed" asserts something false. The declaration now carries `routed` per
site so the gap is declared rather than absent. Conformance remains D4's rule and A10's to apply.

**C5. D1's "six normative sites" was a count without an enumeration (A11).** The check A11 is asked
to build fails when a normative statement appears *outside the six* — unenforceable while "the six"
names no locations. Two defensible sixes existed. D1 is amended to enumerate them by section;
`anchors.json` records all thirteen normative-region mentions, 6 anchors and 7 references, each with
a named reviewer.

Plan corrections: A5's row-2 citation (`:222` → `:287`); WI-B4's abstract "the classifier-2 target"
now names `make ext_call_inventory` / `ext_call_inventory_selftest`, with the note that classifier 2
re-derives its own membership so the repin step is to **read and reconcile** the printed set rather
than re-specify it; A11's size row recorded as measured.

**Upstream: FILED 2026-08-03, ticket `fb_6c81854baf59b316`** (follow-up to `fb_d230853828108783`).
Re-reproduced before filing, with one correction to this note's original claim: **the
absolute-versus-relative distinction does not hold** — both forms fail `MOD010` identically from the
repo root. What does reproduce, and is the sharper finding, is that **both fixes the error message
itself suggests are unusable**: `--relax-modules` is rejected as `flag provided but not defined`,
`AILANG_RELAX_MODULES=1` is ignored, and `ailang check` honours that same env var on the same file.
The error is unactionable exactly as printed.

## Standing rules

**S1 held, and its "completeness, not determinism" half did the work in all three items.** A4's
acceptance is the fixture suite, not the HEAD run — and all five fixtures **type-check**, so the
unresolvable forms are real AILANG an extension could write today rather than illustrations. A5's
set-completeness fixture is the one that separates the validator from a row-shape validator, and the
DST script asserts it fires **alone**. A11's two halves are both required and the *green* one is the
falsifiable half.

Each detector also carries a negative control on itself — a fixture that must come back clean, a
`validate_at_load` that must accept, an ADR passage set that must match — because a detector that
only ever fires passes a suite of only-failing fixtures while being useless.

**S2 was load-bearing in A4's design** and is why `unrouted` is a distinct membership state rather
than folded into non-member.

**S3 did not apply** — no seam ordering in this cluster.

**S4 does not transfer**, as above; the proposed third model is round trips to green, weighted by how
loudly each defect fails.

## Handoff notes for cluster 5 (WI-A10)

A10 is now unblocked and consumes all three. Concretely available to it:

- `dst_attribution_table.validate_at_load(loading_against, discovered)` — the whole load-time gate in
  one call. A10 supplies the current source revision and the discovered site set.
- `table_identity()` — the `(source revision, content hash)` pair a profile records. **A table
  correction re-issues every referring profile**, as D4 states.
- `reachable_core_sites(installed)` — unconditional core plus attributed-and-intersecting.
- `make ext_call_inventory --json` — `classifier_2_set`, `unrouted_fields`, `member_call_sites`,
  `unresolved`, and the per-field membership rationale, for the manifest's derived-set records.

Two things A10 must decide that this cluster deliberately did not:

1. **Whether a profile with an unrouted reachable core site is conformant.** Two exist
   (`session.ail:796`, `stub_step.ail:146`), both declared. D4's all-or-nothing rule points at
   non-conformant; whether `stub_step.ail:146` is even in a deterministic profile's reachable set is
   the live question, since `live_ports` is not the adapter a deterministic run uses.
2. **`driver_only`'s routed-set claim**, left alone here as instructed. The table it needs now
   exists.

The interprocedural attribution-necessity validator remains **unbuilt and unscheduled**, per D4.
Row 2's necessity rests on its named reviewer and says so in the module.
