# Handoff: execute WI-A13 stage 6 — D8's persistence obligations

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-A13 stage 6 of six — the last one.** Stages 1–5 are landed and green (`9c4d724`, `8b0d605`,
`2d752da`, `f77adf1`, `177d0cb` + `be8393c`). `make dst`: exit 0, 403 checks. **When this lands,
WI-A13 is complete and A14 and A15 are unblocked.**

**Read first:** `NOTE-cluster-11-execution-report-and-plan-corrections.md`, whose closing section is
addressed to you, then the plan's `## Standing rules`. **S7 and S8 both bite here**, and S8 gained
its complement from stage 5 specifically because A14/A15 — and this stage's encoding — have the same
exposure.

## Mission

D8's persistence obligations, in two commits:

1. **Secret handling** — programs carry synthetic values only; environment maps and interaction
   artifacts **reject or redact** secret-shaped or live credentials **before persistence**.
2. **The deterministic, diffable encoding and its explicit compatibility policy** — a schema
   migration must either preserve old-program decoding or provide a pinned runner/artifact.
   **Silently reinterpreting an old program is forbidden.** The ADR's Non-goals delegates the
   encoding *and the storage path* to this plan, so choosing them is yours; say why.

Also D8's clause that is easy to skim past: *"Large exact payloads may live in a CI artifact
addressed by digest; **a digest without retained bytes is not sufficient for replay**."* A
digest-only reference is not a permitted representation.

## The starting position, verified — and it is what makes the rule below sharp

**Nothing writes a program to disk today.** `grep -rln 'writeFile\|readFile' src/core/dst_*.ail
scripts/dst/*.ail` is empty. Payload-level codecs exist (`ports.ail:845-912`,
`encode_provider_outcome` / `decode_tool_outcome` and their round-trip rows) but there is no
program-level encoding and no persistence path. **You are building both from nothing.**

## The rule you will break by accident

**A compatibility policy needs a frozen artifact from the past, or it tests nothing — and this
project has no past, so you must manufacture one deliberately.**

You will write the encoder and the decoder in the same commit. They will agree **by construction**.
Every round-trip test will pass, and the clause that actually matters — *silently reinterpreting an
old program is forbidden* — will have nothing to be tested against, because there is no old program.
The policy ships as prose, the gate is green, and the first real migration discovers it.

This is not hypothetical. Cluster 9 hit the in-memory form: a program discovered before its commit
became undecodable by the build after it, and **failed closed with a named refusal rather than
replaying short.** That was D8's policy working on its first real test — and it worked because the
old shape genuinely existed. Once artifacts are persisted, that only keeps working if a specimen is
kept.

So: **freeze a v1 specimen at the moment the encoding lands — the bytes, checked into the tree — and
assert the current build either decodes it correctly or refuses it by name.** Never silently
reinterprets. That fixture is the compatibility policy; everything else is a description of it.

Per S8's complement: **a specimen certifies exactly the shapes it contains.** A minimal specimen
pins a minimal migration. Give it every shape the schema admits — the same obligation S7 puts on a
surviving fixture, and stage 4's technique applies: if a generated program can supply the specimen,
sweep and filter rather than hand-authoring one.

## The decision this stage owns

**Site 22: the artifact name D8 specifies is not unique, and you must not file under a key you
believe to be unique.**

D8 names a preserved failure by `(generator_id, generator_version, seed)`. Stage 5 measured that
`seed_state` is `in_range(salt_hash("${id}/${version}") + seed)` — the version hash and the seed are
**added**, hence interchangeable — so **version `"2"` at seed *s* is byte-identical to version `"1"`
at seed *s+1*, confirmed across all 259 adjacent pairs, twice.** An artifact filed at (v1, seed 4)
and one at (v2, seed 3) are the same program claiming different generator versions.

Two legitimate outcomes, and the wrong third is silence:

- **Fix `seed_state`** — mix the identity through a Lehmer step instead of adding it — which remaps
  the whole stream and moves stage 4's pinned seeds 9, 13 and 94, **each of which has an asserted
  reason**, forcing a 260-seed census re-sweep *through the real driver*. That is a change to a
  landed stage's searched fixtures; if you take it, say so loudly and re-pin rather than relax.
- **Record the collision as a known property of the artifact store**, and key on something that is
  actually unique.

`test_a_version_bump_is_currently_only_a_seed_offset` (`dst_generator.ail:1492`) pins the defective
identity **and is supposed to fail when the defect is fixed.** If you fix it, that test goes red on
purpose — read the comment above it and delete it deliberately.

## Inputs, verified at HEAD

**Run `git diff --stat ad03ab5..HEAD -- src packages scripts Makefile` first; if non-empty,
re-verify.**

| Input | Where |
|---|---|
| `ExecutionProgram`, `DiscoveryConfig`, `InitialWorld`, the pure structural validator | `dst_program.ail` |
| `Interaction`, `CausalIdentity`, `TimedOutcome` (std-only leaf) | `dst_interaction.ail` |
| Payload codecs + their round-trip rows — **the pattern to follow, and the shape of their failure** | `ports.ail:845-912` |
| `RegressionReplay`, `regression_replay_findings`, `regression_report` — **the natural consumer of a persisted program from an older build**; its `differences` is already a list of typed `ReplayMismatch`, so D11 can read it without a second projection | `dst_replay.ail` |
| `strict_replay_findings`, `world_state_of`, the refusal type | `dst_replay.ail` |
| The generator, its bounds, `canary_row`, the pinned tables | `dst_generator.ail` |
| The env key derivation — the driver's 6 sites / 7 keys, source-derived | `dst_discovery.ail:164` |

**The canary is not pinned to the program encoding**, so you may change that encoding freely without
producing canary false alarms — stage 5's stop-condition on exactly this did not fire, because the
canary digests `dst_generator`'s own decision records, upstream of anything `dst_program` encodes.

## Definition of done

**Secret handling, green.** A secret-shaped fixture is rejected or redacted **before** persistence —
assert the ordering, because redaction that happens after the bytes exist has already leaked, and
both arrangements type-check. Per S8, the fixture must contain shapes **the specification protects**,
not shapes the redactor was written to catch: a redactor tested only against its own known patterns
certifies nothing. The driver's seven env keys (`dst_discovery.ail:164`) are the concrete surface.

**The encoding, green.** Deterministic and diffable — assert both: the same program encodes
byte-identically twice, and a one-field change produces a small, localised diff rather than a
whole-file churn, which is what "diffable" is *for*. Round-trip **field by field with every field
holding a distinct value** (S7's record-level form) — the failure mode is a field the encoder writes
and the decoder ignores, which type-checks on both sides and is silent until a replay serves a
different response while every count balances.

**The compatibility policy, green.** The frozen v1 specimen above, plus: an artifact whose schema
version the build does not know **fails closed with a named refusal**; and a migration path that
either decodes an old specimen or names its pinned runner. No path silently reinterprets.

**Site 22 decided**, with its reasoning recorded and, if fixed, the re-sweep done and the pinned
test deleted deliberately.

**Existing gates green**, `make dst` read by **exit status**, every structural guard mutation-tested,
and any new grep-based Makefile guard anchored to a syntactic form.

## Out of scope

- **The CI replay affordance** — D8 requires CI output to carry a copy-pasteable local replay command
  or artifact reference; this plan assigns it to **WI-A14**, where the failure report is produced.
- **A14's invariant set, the D4 latency pair, D11 reporting; A15's corpora.**
- **The provider fault and latency channels** — A14's, one `ScriptedStep` field away (cluster 10).
- **`routing_violation_at`'s call site** — WI-C5's, on structural grounds (cluster 9).
- **Shrinking** — deferred past the first name-adoption gate and recorded as such.

## Stop and report rather than deciding inline

- **If fixing `seed_state` is the right call but the re-sweep is larger than this stage can carry**,
  stop and report — the decision is the deliverable, and a half-done remap that leaves stage 4's
  pinned seeds stale is worse than either outcome.
- **If a secret-shaped value cannot be redacted without making a program unreplayable**, that is a D8
  finding: the environment map is a replay input, and redacting a value the run depended on changes
  the trajectory. Report the tension rather than choosing silently.
- If the encoding cannot be made diffable without sacrificing determinism, say which you chose and
  why — D8 asks for both and the plan owns the trade.

## Traps

**Run `make dst` and read `$?`.** Fourth consecutive stage where this mattered. **Do not run other
`make` targets concurrently with it.** Note the single `✗` in a green `dst` log is the `✗ Failed: 0`
summary label of a passing `ailang test` run — check it rather than assuming either way.

**A5 anchors: `stub_step.ail:161`, `session.ail`'s 948/1053/2290/2400; `driver_only` is v3.** Stage 5
disturbed none and paid nothing. Write below anchors, widen lines and import lists in place, and run
`sed -n '161p'` after each edit — it caught a violation immediately in stage 4. **Adding a
`StepProvider` variant forces a match arm that cannot sit below the sites it precedes and pays a
re-issue; not adding one does not.**

**Check your constructor imports before writing a match** — an out-of-scope pattern head binds as a
fresh variable, the arm is irrefutable, later arms are dead, `ailang check` is clean. It cost cluster
9 a decoder returning fallbacks for every field, which is *this stage's exact subject matter*. Written
up in `.agent/issues/ailang-no-warning-for-unreachable-match-arm.md`.

Clear `.ailang/cache` before believing a contradicting type error. Rebuild the parallel `ailang check`
closure tool. Never probe from `/tmp`. Pin is v0.26.0.

## Report back

Twelfth calibration run, and **the last of WI-A13** — so the report should close the item as well as
the stage.

- **Time and the recorded-binding count, split decided versus discovered, and per piece** — S6 now
  carries both refinements. Stages 1–5 ran 1/3/3/4/5 bindings at 1×/3×/~3×/~1.5×/~0.9×, and stage 5
  was where the count first over-predicted, because its two pieces did not interact. This stage's two
  pieces are also largely independent.
- **Judgement ratio, split** machinery versus content, per piece. Stage 5 was ~20% (regression
  replay) / ~60% (canary) / ~25% (pins), and the content figure fell because the *filter* was derived
  rather than authored.
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** Twenty-two across eleven clusters; **determinism has caught none of them.**
- **A closing view of WI-A13 as a whole**: six stages, what the staging got right and wrong — it was
  re-cut once mid-flight when the seeded generator was found to have fallen between stages — and what
  A14 should know that no single stage report says.
