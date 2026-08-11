# Handoff: execute WI-A13 stage 5 — regression replay and D8's generator canary

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-A13 stage 5 of six.** Stages 1–4 are landed and green (`9c4d724` types + validator, `8b0d605`
discovery recording, `2d752da` strict replay, `f77adf1` the seeded generator). `make dst`: exit 0,
387 checks. Stage 6 — D8's persistence obligations — is not started.

**Read first:** `NOTE-cluster-10-execution-report-and-plan-corrections.md`, whose closing section is
addressed to you, then the plan's `## Standing rules`. **S8 was written for this stage's canary**;
S1 and S7 bind as always.

## Mission

Two pieces, **two commits**, and they are independent of each other:

1. **Regression replay** — D2's second replay mode. Does *not* need the generator; stage 3 left the
   exact seam.
2. **D8's generator canary** — pinned per stable generator id, failing if a seed remap occurs
   without a `generator_version` bump. This needed stage 4 and could not have been built before it.

Take regression replay first: it is cheaper, ready, and independent, so it converts to a clean stop
if the session runs long.

## The rule you will break by accident — one per piece

### Regression replay: demote exactly two rules, and not the one that looks similar

D2 permits regression replay to *"require compatible causal identity, record projection differences,
and continue"* — but binds it with *"never weakens tool-call/result correlation or delivers an
outcome to a different logical request."* **That line is already a line in the code**, and the
temptation is to demote one rule too many.

`ReplayMismatch` (`dst_replay.ail:135-141`), in `compare_at`'s coarsest-first order:

| Variant | Regression mode |
|---|---|
| `WrongKind` | **stays fatal** |
| `WrongOrigin` | **stays fatal** |
| `UnsafeIdentity` | **stays fatal** — this *is* the correlation guarantee |
| `ProjectionDiffers` | demote to a recorded difference |
| `OutcomeDiffers` | demote to a recorded difference |
| `ProgramExhausted` | **stays fatal** |
| `UnusedInteraction` | **stays fatal** — and it is the one most easily forgotten, because *nothing fails without it*; the module says so at `:129` |

Demoting `UnsafeIdentity` produces a regression mode that runs further, reports more, looks more
useful, and has silently given up the one thing D2 says it may never give up. It type-checks.

### The canary: a canary that is regenerated when it fails is not a canary

This is the distinctive failure mode of pinned artifacts and no existing rule covers it. D8 requires
the canary to **fail** when a seed remap happens without a version bump. A failure is therefore a
*decision point* with exactly two legitimate outcomes:

- the remap was intended → **bump `generator_version` and re-pin deliberately**, or
- it was not → **fix the generator.**

If the workflow is "canary went red, regenerate the pin", both outcomes collapse into silence and the
artifact certifies nothing while looking green forever. **Do not add a regeneration target, a
`--update` flag, or an `ACCEPT=1` escape hatch.** If re-pinning needs to be easy, make it a
documented manual edit whose diff a reviewer sees.

**And per S8, pin something reachable only through a choice.** Site 21 is the reason this is stated:
stage 4's generator responded to its seed through a *decorative string* — the seed printed into a
payload — and the seed-sensitivity axis passed while every trajectory was byte-identical in shape. A
canary pinning a program digest is only meaningful if the digest cannot be reached except through a
draw. `seeded_generator_dst`'s axis A is the model; **its anti-count control and its whole-state
mutant are both load-bearing and neither survives being copied carelessly.**

## Inputs, verified at HEAD

**Run `git diff --stat a9257a2..HEAD -- src packages scripts Makefile` first; if non-empty,
re-verify.**

| Input | Where |
|---|---|
| `ReplayMismatch` (7 variants), `compare_at`, `strict_replay_findings(program, actual)` | `dst_replay.ail:135-141`, `:294` |
| `world_state_of`, the reconstitution balance, the refusal type | `dst_replay.ail` |
| `seed_state(id, version, seed)` — **the version is mixed into the initial Lehmer state** | `dst_generator.ail:362` |
| `generator_state(id, version, seed, bounds)` | `dst_generator.ail:366` |
| `check_seed_sensitivity`, the bounds and bound-failure record | `dst_generator.ail` |
| The generating adapters — `WorldState.gen`, `generating_ports`, the `GeneratedWorld` arm | `ports.ail`, `stub_step.ail`, `session.ail` |
| Two-sided completeness witnesses — `check_discovery`, `discovery_ok`, `class_balance` | `dst_discovery.ail:348, 366, 270` |
| A precedent worth reading, not copying | `scripts/dst/compaction_seeded_dst.ail:94` `run_rng_canary` |

**The pinned seeds are 9, 13 and 94, and each has an asserted reason rather than a described one**
(`seeded_generator_dst.ail:26, 69, 96`): 9 and 13 are the equal-census anti-count pair; 94 is one of
exactly two seeds under 260 satisfying S7's two obligations. A change to the generator, to a
request-projection string, or to the driver's control flow moves all three, loudly. **Re-sweep and
re-pin; do not relax the check.**

**`generator_version` is mixed into `seed_state`**, so a version bump moves the whole stream at every
seed. D2 permits that difference and D8 requires the version to travel with the artifact —
`check_seed_sensitivity`'s `versioned` row already asserts it, and **that row is where the canary
attaches.**

## Definition of done

**Regression replay, green.** Compatible causal identity required; projection and outcome differences
**recorded and reported**, not discarded; the five fatal rules above still fatal; a fixture per
demoted rule showing it recorded rather than failing, and a fixture per fatal rule showing it still
fails. Strict replay's behaviour unchanged — assert that, because sharing `compare_at` makes a
regression-mode edit able to weaken strict mode silently.

**The canary, green.** Pinned per stable generator id. Demonstrated **red** by a deliberate seed
remap with no version bump — the mutation-test obligation (C5), and here it is the entire point of
the artifact. Demonstrated **green** after a version bump that legitimately remaps. No regeneration
path, per above.

**Per S7, asserted executably:** whatever fixture survives carries every shape the specification
protects with **no two of its quantities equal**. Stage 4 satisfied this by *searching* — 260 seeds
filtered on S7's own obligations, two qualifying — and that technique transfers directly here.

**Existing gates green**, `make dst` read by exit status, and any new grep-based Makefile guard
anchored to a syntactic form.

## Out of scope

- **D8's persistence obligations** — stage 6: secret redaction before persistence, and the
  deterministic diffable encoding with its compatibility policy.
- **A14's invariant set, the D4 latency pair, D11 reporting**; **A15's corpora** — though note A15
  should select corpora by the same sweep-and-filter technique, and this stage's canary is the
  precedent for how a pinned artifact is kept honest.
- **`routing_violation_at`'s call site** — WI-C5's, on structural grounds (cluster 9).
- **The provider fault and latency channels** — A14's, one `ScriptedStep` field away, deliberately
  not added by stage 4 (cluster 10, correction 2).

## Stop and report rather than deciding inline

- **If a demoted rule turns out to be load-bearing for correlation**, that is a D2 finding — report
  it rather than re-promoting quietly, because the demotion set is the substance of this mode.
- **If the canary cannot be made to fail** on a deliberate remap, stop: that means it is pinning
  something not reachable through a choice, which is site 21's defect in the artifact built to
  prevent it.
- If pinning requires the program encoding to stabilise in a way stage 6 would change, say so — the
  encoding is stage 6's and a canary pinned to an unstable encoding will produce false alarms that
  invite exactly the regeneration path this handoff forbids.

## Traps

**Run `make dst` and read `$?`.** Third consecutive cluster where this mattered — cluster 10's
attribution cascade produced four ✗ among 382 ✓ under `--keep-going`. **Do not run other `make`
targets concurrently with it.**

**A5 anchors: `stub_step.ail:161`, and `session.ail`'s four are now at 948/1053/2290/2400.**
`driver_only` is at **v3**. Cluster 10 kept `:161` intact by writing below it and widening lines and
import lists in place, with `sed -n '161p'` after each edit — which caught one violation immediately.
But it disturbed the `session.ail` four anyway, because a new `StepProvider` variant forces an
exhaustively-checked match arm that cannot sit below the sites it precedes. **A stage-5 edit adding
another variant pays the re-issue; one that does not, does not.**

**Check your constructor imports before writing a match** — an out-of-scope pattern head binds as a
fresh variable, the arm is irrefutable, later arms are dead, and `ailang check` is clean. Written up
in `.agent/issues/ailang-no-warning-for-unreachable-match-arm.md`.

Clear `.ailang/cache` before believing a contradicting type error. Rebuild the parallel `ailang check`
closure tool. Never probe from `/tmp`. Pin is v0.26.0.

## Report back

Eleventh calibration run.

- **Time and the recorded-binding count, split decided versus discovered** — S6's refinement from
  cluster 10. Stages 1–4 ran 1/3/3/4 bindings at 1×/3×/~3×/~1.5×, and stage 4 was the first where two
  bindings *arrived as red gates* rather than from reading the specification.
- **Judgement ratio, split** machinery versus content. Stage 4 was ~45% / ~85%, the machinery half
  the highest of any stage because D2 fixes no distribution, choice surface or arithmetic.
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** Twenty-one across ten clusters; determinism has caught none. **S8 was written from
  site 21 and this stage's canary is its first real test** — if the canary would have passed under a
  weaker mutation before you strengthened it, that is worth reporting as S8 earning its place.
- Anything the plan or ADR got wrong.
