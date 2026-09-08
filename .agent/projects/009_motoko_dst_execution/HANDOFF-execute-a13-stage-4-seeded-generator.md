# Handoff: execute WI-A13 stage 4 — the seeded generator

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-A13 stage 4.** Stages 1 (`9c4d724` types + validator), 2 (`8b0d605` discovery recording) and 3
(`2d752da` strict replay) are landed and green. `make dst`: exit 0, 340 checks.

**Read first:** `NOTE-cluster-9-execution-report-and-plan-corrections.md`, then the plan's
`## Standing rules` — **S1 and S7 are this stage's whole risk**, and S7 was promoted to *executable*
by cluster 9.

## Mission, and a correction to the staging you inherited

**Build D2's seeded generator.** Not regression replay, not the canary — those move to stage 5, and
the reason is a planning defect worth stating rather than quietly rescheduling.

**The original five-stage split described stage 2 as "discovery — record what the real driver
requests." That is only half of D2's discovery.** D2 is *seed-driven*: a schema-versioned generator
**chooses** a compatible response, fault and latency from the request plus explicit generator state,
and the world **records** the choice. Stage 2 built the recording half against hand-authored worlds.
The choosing half was never any stage's, and it fell between stage 2 and stage 4's canary — which
cannot pin a generator that does not exist.

Verified at HEAD: **nothing draws from a seed.** `scripts/dst/discovery_dst.ail:543-545` records
`generator_id: "driver_only_discovery"`, `generator_version: "1"`, **`seed: 0`** on hand-authored
scenarios. The only `std/rand` mentions under `src/core` are comments *about the guard that forbids
it*.

Corrected remaining staging: **4 — the seeded generator; 5 — regression replay and D8's generator
canary; 6 — D8's persistence obligations.** Regression replay is independently ready (stage 3 left
`compare_at` as exactly the demotion it needs) and may be taken in the same session if time allows —
but the generator is first, because everything downstream needs it and regression replay does not
need the generator.

## The rule you will break by accident

**The program already carries `generator_id`, `generator_version` and `seed` as required, validated,
non-blank fields — so a "generator" that ignores its seed passes every check that exists.**

Stage 1's validator rejects a *blank* generator axis. It cannot tell that `seed: 0` was written by
hand and consulted by nothing. So the characteristic failure here is not a crash, it is:

- a generator that produces **the same program for every seed** — perfectly deterministic, every
  count balances, stage 1's validator green, stage 2's two-sided witnesses green, stage 3's strict
  replay green, `make dst` green;
- and a canary in stage 5 that pins those three *literals*, passes, and certifies nothing.

That is the frozen-cursor defect wearing generator clothing, and **determinism is 0-for-19 across
nine clusters** — it would be 0-for-20 here, because a generator that ignores its seed is *more*
reproducible, not less.

**So the assertion, written before the generator (S1): changing the seed changes the program, and
changing nothing else changes nothing.** Concretely — two seeds over the same
`DiscoveryConfig` must produce programs that differ in at least one recorded outcome; the same seed
twice must produce byte-identical programs; and a `generator_version` bump with the same seed is
*permitted* to differ, which is what stage 5's canary will later pin.

A count-shaped check cannot see this: two programs with the same number of interactions and different
contents are the exact shape cluster 9's site 19 established a count is blind to. Compare **contents**.

## The constraint that shapes the design

**`std/rand` is forbidden in `src/core`, structurally and deliberately.** `make world_state` asserts
`grep -l '^import std/rand' src/core/*.ail` is empty (`Makefile:605`), because D1 names an ambient
RNG as a prohibited hiding place for world state. That guard is not an obstacle to work around — it
is the reason the generator must be what D2 already requires:

> Each discovery choice is a deterministic function of generator id/version, seed, generator state,
> the bounded request projection, and current world state. **No ambient RNG participates.**

So: an explicit, seeded, state-threaded PRNG whose state is a value you thread, exactly like every
other cursor this project has built. Cluster 6's lesson applies directly — **the state must be
threaded, not captured**, or you reproduce F6 a third time.

Note the guard greps `src/core/*.ail` only. Putting the generator elsewhere to dodge it would satisfy
the letter and break D1; if the generator lives outside `src/core`, extend the guard's scope in the
same commit.

## Inputs, verified at HEAD

**Run `git diff --stat 65ed0b0..HEAD -- src packages scripts Makefile` first; if non-empty,
re-verify.**

| Input | Where |
|---|---|
| `DiscoveryConfig` — carries `generator_id`, `generator_version`, `seed`, `initial_world` | `dst_program.ail:98-100` |
| `ExecutionProgram` + the pure structural validator + `GeneratorBounds` | `dst_program.ail` |
| `Interaction`, `CausalIdentity`, `TimedOutcome` (std-only leaf) | `dst_interaction.ail` |
| The recording seams — `WorldState.log`, `record_interaction`, `RecordingWorld`, `recording_ports` | `ports.ail`, `stub_step.ail:68, 316` |
| Two-sided completeness witnesses — `check_discovery`, `discovery_ok`, `class_balance` | `dst_discovery.ail:348, 366, 270` |
| `world_state_of`, `strict_replay_findings`, `compare_at` | `dst_replay.ail` |
| `driver_only()` v2, `validate_driver_only`, `driver_only_manifest` | `dst_driver_only.ail:99, 232, 250` |
| The randomness guard | `Makefile:605` |

## Definition of done

**The generator, green.** Deterministic in exactly D2's five inputs; declared bounds on interactions,
stream chunks, payload bytes, logical-resource size and clock advancement, with **exceeding a bound a
generator failure, not an unbounded run**; chooses only at requests the real driver actually makes,
never inventing a request disconnected from production control flow.

**The seed-sensitivity assertion**, per the rule above, landed **before** the generator and shown red
against a seed-ignoring stub.

**Per S7, asserted executably rather than satisfied:** a surviving fixture carrying every shape the
specification protects, **with no two of its quantities equal**. Cluster 9's `rich` scenario is the
worked example — provider 5, script 4, approval reads 6, approvals consumed 3, tool dispatches 2 —
and cluster 8's `eof` is why: a fixture whose quantities are all equal cannot distinguish which
quantity a check is reading.

**Existing gates still green**, and the generated programs must pass **stage 1's validator** and
**stage 3's strict replay** — a generated program that cannot be replayed is the strongest available
sign the generator is inventing rather than choosing.

**Every structural guard mutation-tested** (C5), and any new grep-based Makefile guard **anchored to
a syntactic form** — a bare-token guard eventually fires on the artifact documenting it, which kept
`make world_state` red for two clusters.

## Out of scope

- **Regression replay and the canary** — stage 5, unless time allows and you say so explicitly.
- **D8's persistence obligations** — stage 6.
- **A14's invariant set, the D4 latency pair, D11 reporting**; **A15's corpora**. The latency pair
  will consume this generator; do not build it here.
- **`routing_violation_at`'s call site** — reassigned to WI-C5 by cluster 9 on structural grounds.

## Stop and report rather than deciding inline

- **If a generated program cannot be strictly replayed**, that is a finding about the generator or
  about D2, not a reason to relax stage 3. Stage 3's refusal path was built to fail closed.
- **If seed sensitivity cannot be asserted** without comparing whole programs byte-for-byte — i.e. if
  there is no meaningful content-level difference to point at — say so; that would mean the generator
  has no real choice surface yet, which is a scope finding.
- If declared bounds cannot be expressed without widening `ExecutionProgram`, see `dst_program`'s
  design note 3 before adding a field.

## Traps

**Run `make dst` and read `$?`** — not a scan of output; it was red for two clusters because
`--keep-going` made a failure one line among 233 green ones. **Do not run other `make` targets
concurrently with it.**

**`stub_step.ail:161` is an A5 attribution anchor.** Insert below it and widen import lists in place
rather than by adding a line; one `sed -n '161p'` check costs seconds and avoids a five-artifact
cascade including a mandatory `driver_only` re-issue. Cluster 8 paid that cascade; cluster 9 avoided
it entirely this way.

**Check your constructor imports before writing a match.** An out-of-scope pattern head binds as a
fresh variable, making the arm irrefutable and later arms dead, with `ailang check` clean — it cost
cluster 9 a decoder returning fallbacks for every field. Written up in
`.agent/issues/ailang-no-warning-for-unreachable-match-arm.md`.

Clear `.ailang/cache` before believing a contradicting type error. Rebuild the parallel `ailang check`
closure tool (~1.7 s over the 13-module closure). Never probe from `/tmp`. Pin is v0.26.0.

## Report back

Tenth calibration run.

- **Time and the recorded-binding count.** S6's generalised second term — *any fact that cannot be
  read and must be decided* — has predicted three stages running (1, 3, 3 bindings; 1×, 3×, ~3×).
  The generator has an obvious candidate binding in the PRNG choice itself, which D2 does not fix.
- **Judgement ratio, split** machinery versus content. Stage 3 was ~35% / ~90%.
- **Whether any site admitted two type-checking answers with a silent wrong one, and what caught it.**
  Nineteen across nine clusters; determinism has caught none. **If the seed-sensitivity assertion
  catches a generator that ignores its seed, report it — that is this stage's central result**, the
  same way witness grading was stage 3's.
- Anything the plan or ADR got wrong. **This handoff already carries one planning defect of mine** —
  the generator falling between stages — so treat the staging itself as fair game.
