# WI-D3 — the filesystem world class. **ROW 10 CLOSES. C4's TABLE IS GREEN. THE NAME IS NOT ADOPTED.**

Twenty-seventh calibration run, and the last row. Written against HEAD `77c44d3`, branch
`arniwesth/mot-66-close-acceptance-row-10`.

## Window

**~2h05m** wall-clock: `2026-08-05T17:45Z` → `2026-08-05T19:50Z`. Grounding was clean: `git status`
clean at `77c44d3`, and the handoff's branch name matches the branch — third item running.

## THE ANSWER

**Acceptance row 10 is GREEN, so all eleven of C4's rows now hold.** The host-env class has a
two-sided poison pair, and so does a filesystem class that did not exist this morning.

| | before | after |
|---|---|---|
| Effect classes with a two-sided poison pair | 3 (AI, Clock, tool contract) | **5** (+ host-env, + filesystem) |
| `resolve_context_limit` call sites reading the host | 8 | **0** |
| `Ports` seams | 5 | **6** (`file_read`) |
| `driver_env_keys()` | 7 | **11** |
| C4's acceptance rows holding | 10 of 11 | **11 of 11** |

**A GREEN TABLE IS NOT AN ADOPTED NAME, and this item does not adopt one.** See the last section —
that sentence is the reason it is written before anything else.

## Both halves of the pair, and what produces each (S16)

Two classes, four runs, and the four are **one subject with one difference**:

```
✓ deterministic world completes with Env withheld     ✓ live world dies with Env withheld
✓ deterministic world completes with FS  withheld     ✓ live world dies with FS  withheld
```

**The producer of every one of those four rows is OUT OF PROCESS: the AILANG interpreter's capability
check terminates the run, and the exit code is the whole observation.** Nothing in this tree computes
them, no assertion in the driver participates, and the poison script cannot make itself pass — which
is what makes the pair stronger than an in-process row and why it is worth the two extra runs.

The deterministic half and the live half run the **same session call**. The only difference between
them is which closures `ported_provider` bound, so a live run dying where the scripted one completes
locates the failure in the binding rather than somewhere in the driver.

**Pinned, not assumed.** Binding `live_ports.file_read` to `scripted_file` makes the FS-withheld LIVE
run **complete** — so the live half's death is at `ambient_file` and not at anything incidental on
the path.

## THE FINDING: the pair is BLIND to a world whose file table is ignored

**MEASURED.** Bind `scripted_file` so it ignores `WorldState.files` entirely — `lookup_file([], path)`
— and **all four halves of the pair stay green**:

```
deterministic, Env withheld: exit=0     live, Env withheld: exit=1
deterministic, FS  withheld: exit=0     live, FS  withheld: exit=1
```

The deterministic runs still perform no ambient read; the live runs still die on `ambient_file`. **A
poison pair is a statement about what a run does NOT read, and it is silent on whether the world is
read at all.** Those are different properties, and only the first is hermeticity.

So the class carries a **provenance assertion** beside the pair, in `world_state_probe`, in the same
shape the env class has needed since A12: the world seeds a profile `agent.context_limit` of 1 at the
path the driver COMPUTES, the run compacts and exhausts, and a control with no file resolves to 0 and
reaches its terminator. The checkout's real `.motoko/config/default/config.json` declares no
`agent.context_limit`, so the world cannot pass by agreeing with the host. That assertion goes red on
the ignored-table mutant while every pair row stays green.

**This is S16's shape and it is the item's central result.** It is also the reason the env class's
existing provenance assertion is KEPT rather than retired: C4 ruled that provenance is not
hermeticity, and the converse turns out to hold just as strictly — hermeticity is not provenance.

## The C1b defect, reproduced deliberately and caught twice

The handoff named one way this item could ship something worse than it replaced: route the env half
and leave the file half ambient, so the probe passes an Env poison probe while still reading a host
file. **Written as a mutant and caught by two independent routes:**

1. the FS-withheld deterministic run dies with a genuine capability error — `effect 'FS' requires
   capability, but none provided`;
2. the file provenance assertion goes red, reporting `finish=stop` for **both** the seeded and the
   unseeded world, which is what an ignored table looks like from outside.

## What was actually wrong, measured before it was designed around

**`resolve_context_limit` was the SOLE cause.** At HEAD, withholding either `Env` or `FS` killed the
deterministic run. Short-circuiting that one function — signature unchanged, so no cascade — made
**both** withheld runs pass. That rules out the second cause the handoff said to stop and report, and
it is why the class is a point read rather than something wider.

**AILANG gates on PERFORMED, not DECLARED — confirmed empirically before the design rested on it.**
`world_state_probe` dispatches seeded tools through `world_tool`, which **declares**
`! {IO, Process, FS}`, and completes with `FS` withheld. The declared row says the opposite; the
interpreter demands a capability only when a read happens.

**And the deterministic runs were reading real files today.** `.motoko/model-catalog.json` carries
`"test/tiny": 100`, and every resolution read `.motoko/config/default/config.json`. The DST fixtures
did not depend on the VALUES — their models are absent from the catalogue and resolve to 0 — but the
read was real, and it is the read the row is about.

## The narrowing move, refused

**The existing provenance assertion was not reclassified as "detection".** Row 10 says bypasses "fail
or are detected"; the `MOTOKO_HEADLESS` assertion shows the driver read the world where it was asked
to and says nothing about other code reading the host. It is kept, it is stated as the different claim
it is, and the row is closed on the pair instead.

## Mutation results — four, and two are the item's argument

Restored by `cp` throughout (S17); every file verified byte-identical after each.

| # | Mutant | Result |
|---|---|---|
| M1 | `live_ports` binds `scripted_file` | FS-withheld LIVE run **COMPLETES** — pins the live half's death to `ambient_file` |
| M2 | **env half routed, file half ambient** (C1b) | RED twice — capability death on the FS-withheld deterministic run **and** the provenance assertion |
| M3 | **`scripted_file` ignores `WorldState.files`** | **ALL FOUR PAIR HALVES GREEN**; only the provenance assertion is red |
| M4 | `context_resolutions_per_run()` 12 → 11 | RED, 4 findings per scenario — the env census literal is load-bearing |

## The census cascade, and the instrument correcting me inside one run

Routing the env half grew `driver_env_keys()` from 7 to 11, and the four new keys are the first whose
call site is in neither `session.ail` nor `tool_phase.ail`. Two things followed.

**The `discovery` target's key derivation greps a FILE LIST, and that list is itself a stale-able
literal.** It read two files; the driver's env surface had moved into a third; the derived set came
back four keys short of the declared one and the target failed **loudly**. A derivation whose input
set is wrong disagrees with the literal it checks rather than agreeing with it, which is the property
worth keeping.

**The per-scenario read counts are a measurement, and my first version of them was wrong.** Each
resolution performs five env requests against an empty world — `MOTOKO_PROFILE_DIR`, `MOTOKO_CONFIG`,
`MOTOKO_REPO`, `MOTOKO_MODELS_FILE`, `MOTOKO_REPO` again — so a count needs the number of resolutions
a scenario reaches. I wrote it as a shared constant of 12, correct for discovery's three scenarios
(60 = 12 × 5 on each), and **strict replay rejected it on the next run**: `rich` reaches 19 and
`maxsteps` 8. It is now a per-scenario parameter with each scenario stating its own measurement.

**No formula was fitted.** Three data points — 12 at provider=4, 19 at provider=5, 8 at provider=1 —
do not determine a rule, and deriving the count from the log would put both sides of the check on one
producer, which is exactly S16's defect. The literal goes RED rather than stale when the driver's loop
structure changes, which is the intended failure.

## Row 10, re-answered against the ADR's text

**"Is hermeticity enforced?" — PASS.** The row names four bypasses; each is answered by name.

1. **Ambient effect (AI).** Two-sided pair, unchanged from C4.
2. **Host-env.** Two-sided pair, NEW. All eight `resolve_context_limit` sites routed, plus a
   filesystem class so the env half does not hand back a world-supplied path to a host file.
3. **Clock.** Two-sided pair, unchanged from C4.
4. **RNG.** **Honestly reported as UNUSED, and left exactly as it was** — no driver module under
   `src/core/*.ail` imports `std/rand`, checked structurally, and every run completes without the
   capability ever being granted. It is reported rather than claimed, and that was already correct.

The filesystem class is a **fifth** pair, beyond the four the row enumerates, because the host-env
clause could not be closed without it.

## Recorded bindings: decided versus discovered

**Discovered — a tool or a measurement forced it:**

1. **`resolve_context_limit` is the sole cause of both deaths.** Short-circuit measurement at HEAD.
2. **Declared ≠ performed, confirmed on `world_tool`** before the pair was designed around it.
3. **The pair cannot see an ignored world table** (M3). The reason the provenance assertion exists.
4. **The Makefile's deferral note UNDERCOUNTED the call sites** — it said six; there are eight, six in
   `session.ail` and two in `rpc.ail`.
5. **The env census literal is per-scenario, not global** — caught by `strict_replay` in one run.
6. **`dst_profile_coverage.ail`'s `stub_step.ail:133` anchor was stale AT HEAD**, pointing at a
   comment about scripted chunk `Usage` rather than at the `on_describe_tools` call it names. Verified
   against HEAD before any WI-D3 edit, so it is pre-existing. Nothing checks it: `make anchors` covers
   the A5 attribution set, and this one is prose in a coverage module's header.
7. **`long_qwen_compaction_dst` depended on the PROCESS ENVIRONMENT, not just on a host file.** Its
   context limit came from `MOTOKO_MODELS_FILE`, which the `compaction_dst` RECIPE set, pointing at
   `scripts/fixtures/qwen36-small-model-catalog.json` — so the suite's behaviour was a property of how
   the target was invoked. Both halves were ambient and both were load-bearing: with the world serving
   neither, two scenarios stop reaching their invariants. The world declares both now and **the recipe
   no longer sets the variable**.
8. **Routing puts the driver's config reads into the RECORDED INTERACTION LOG** — 15 extra
   interactions on the shortest run and up to 95 on the measured suites, because the driver
   re-resolves a static value on every loop arm. Invisible while the reads were ambient. This is what
   `seeded_generator` and `corpus_pr` are red on; see the gate state.
9. **Two hand-maintained env fixtures were keyed to the 7-key surface and went red on the 11-key one**
   — `run_report_dst`'s multiplicity fixture (its assertion is `total > key count`, and 9 > 11 is
   false) and `program_persistence_dst`'s `synthetic_env`, whose scenario 3 asserts the fixture IS
   `driver_env_keys()`. **The second is the one worth naming: four new keys entering the recorded log
   enter every persisted artifact, so they are part of the surface the redaction detector covers**, and
   it said so — `4 driver key(s) carried a credential past the detector`.
10. **Two cascade sites are reachable ONLY by the whole-tree sweep** — `long_qwen_compaction_dst`
   builds a `Ports` field by field (so a new seam is a type error rather than an inheritance) and
   `recorded_stream_dst`'s `main_adoption` row had to widen by `FS`. Neither is compiled by any
   `make dst` target. S13, fifth consecutive item to be paid by it.

**Decided — a human chose:**

1. **`ContextReader`, a two-seam PROJECTION of `Ports`**, rather than passing the whole record.
   `context_reader_of` is the driver's only constructor, so the seam bound here and the seam bound in
   `Ports` are one closure value. Demanding the whole record would force the three catalogue probes to
   acquire a `model_step` they have no use for.
2. **An absent path reads as ABSENT and does NOT fall back to the host.** The one place this class
   deliberately differs from `tools`, whose empty queue delegates to the real dispatcher: a tool the
   world has no opinion about must still run; a FILE the world has no opinion about is the ambient
   dependency this class exists to remove.
3. **`present` is carried explicitly**, not inferred from empty content — `ApprovalInput.eof`'s reason,
   and `context_usage` guards every `readFile` with a `fileExists` that branches on exactly that.
4. **One `file_read` request replaces `fileExists` + `readFile`.** Two observations of a filesystem
   that can disagree between them become one request the world can serve and a replay can reproduce.
5. **`--entry main_host_class`, not a `POISON_ARM` value.** `main` selects its arm with `getEnvOr`,
   which performs an Env read BEFORE any subject, so an Env-withheld run of `main` would die on the
   selector and report a non-zero exit establishing nothing. `declared_vs_performed.ail` already made
   this choice and says why; this is the second instance of the same reasoning.
6. **The recording and generating adapters inherit `scripted_file` and log no file interactions.** The
   reason is a measurement: every fixture in this tree leaves `files` empty, so every read is absent
   and `world_state_of` reconstitutes the world those runs actually had. **What would have to CHANGE**
   is named rather than located — `dst_interaction.IdentityBody` would need a file-read variant and
   `world_state_of` would need to derive `files` from it.
7. **`ambient_env` hoisted out of `live_ports`' inline closure** into `ports.ail`, so the seam a poison
   run exercises and the seam a live session exercises are one function and cannot drift.
8. **`files` crosses the extension world token.** The driver ADOPTS the world a hook returns at five
   `token_to_world` sites, so a field the encoder omits is a field every hook silently empties
   mid-run. The decoder half is forced by the type checker; **the encoder half is not**, so
   `codec_fixture_world` carries two entries including a present-but-empty path — the one state
   `FileRead.present` expresses that content alone cannot.
9. **`FS` is NOT added to `driver_only.forbidden_capabilities`.** The claim would be true and
   instrumented, but it is a PROFILE claim with its own coverage row, waiver review and version bump,
   and this item's remit was the world class and row 10. Named rather than located.
10. **`rpc` binds the ambient reader and drops the successor**, and that costs nothing rather than
    being excused: both ambient bindings return `next_state: state` unchanged, so there is no
    successor to lose.
11. **The two sibling `st.world_state` finalize sites take `st_ctx`** — not to close them, which is out
    of scope, but so this item does not newly widen them. They still ignore `chain.next_state`.

## Sites where two answers type-checked and one was silently wrong

**This item wrote production code and authored none in the tree.** Every alternative that type-checked
was caught by a gate that existed before the change (S1) or by the compiler.

**One is counted, and it is in the INSTRUMENT rather than the tree — D2's precedent exactly.**
`make world_state` was **completely green, all five classes, both halves each**, before the file
provenance assertion existed. That gate type-checks, passes, and is green over a `scripted_file` that
ignores the world's table entirely — M3. It was never the shipped gate, but it was the gate that
"row 10 is closed" would have rested on had the item stopped when the pairs went green, which they
did. **The counter is 54**, from D2's 53, attributed to this item's own gate.

**Determinism has still caught none of the fifty-four.**

Worth recording separately and NOT counted: the shared `context_resolutions_per_run() = 12` literal
was wrong and type-checked, but it went red on the next run of an assertion that predates it. That is
S1 working, not a silent site.

## Stale reasons and prose: TEN sites, where the handoff named ONE

The handoff named the Makefile note it asked this item to delete. The other eight were found by
grepping for the claims the change falsifies.

| # | Site | Claim that expired |
|---|---|---|
| 1 | `Makefile` `world_state` header | the whole env-class deferral note — **deleted, not edited**, because the thing it deferred exists |
| 2 | the same note, separately | "`resolve_context_limit`, which the driver calls at **six** sites" — it is eight |
| 3 | `dst_driver_only.forbidden_capabilities` | the `Env` row's "PROVENANCE ONLY … the Env-withheld poison pair is deferred" |
| 4 | `session.ail` `session_policy_init` header | "Four of the driver's **seven** env reads" — the driver's key set is eleven |
| 5 | `session.ail` capture-payload site | "the **sixth and last** driver env read" |
| 6 | `dst_discovery.ail` header | the derivation "greps … out of session.ail and tool_phase.ail" — three files now |
| 7 | `dst_profile_coverage.ail` | `stub_step.ail:133`, **stale at HEAD** since WI-A16 and checked by nothing |
| 8 | `ports.ail` `log` field | "the **four** deterministic seams below preserve it" — five |
| 9 | `ports.ail` `gen` field | "The **four** deterministic seams and the four recording ones" — five |
| 10 | `Makefile` `compaction_dst` recipe | `MOTOKO_MODELS_FILE=…` — the world declares it now, so the recipe does not |

**Sites 8 and 9 are the shape worth naming: a count that record update made cheap to break.** Every
`WorldState` literal in the tree but `empty_world_state()` uses `{ empty_world_state() | … }`, which is
exactly why adding a field cost nothing — and exactly why two comments counting the seams went stale
without anything noticing. The mechanism that makes the change safe is the mechanism that makes the
prose rot.

**Sites 4, 5, 8 and 9 are all COUNTS restated beside a derivation that already computes them.** Site 4
now names `dst_discovery.driver_env_keys()` instead of repeating its answer, which is the fifth
consecutive item to carry this class and the first to remove a copy rather than update it.

**Two historical records were deliberately NOT rewritten** — `dst_driver_only.ail`'s v7 and v8 cascade
notes both say `stub_step.ail:202`, and both are records of what was true at WI-C5 and WI-D2. S15's
trap is precisely that a bare number re-dated in a historical record becomes a false claim about
history.

## The anchor cascade, paid ONCE

**Three anchors moved.** `stub_step.ail` 202 → 203 (one import line above it), `session.ail`
2601 → 2654 and 2711 → 2764. `session.ail` 881/1126/1232, `tool_phase.ail` 313/314/373 and
`ext/runtime.ail:190` did not move.

**Every anchor was re-derived and NO JUDGEMENT was available** — one candidate each, the same answer
B4, C1, C3, C5 and D2 all got: `now()` is unique in `stub_step.ail`, and `session.ail` has exactly
four `ports.clock_now(` call sites. **The claim did not change**: same seven sites, same effects, same
routed flags, still 6 routed of 7. WI-D3 adds no clock site — its new ambient reader is
`ports.ambient_file`, and that table is the CLOCK attribution.

`driver_only` re-issued **v8 → v9** with the table's new content hash
(`sha256:affd2463…`, from `sha256:ff487d03…`). **A FOURTH consumer was found beyond D2's set:**
`tools/predicate-anchors/anchors.sh` carries its own copy of the line numbers, and `make anchors` kept
reporting the old ones after every `.ail` consumer was updated.

**Paid exactly once.** S18 is why: all nine comment blocks tensed for S15 were rewritten BEFORE any
anchor number was derived. Line-count neutrality was not available — two record types gained a field
and a module gained two parameters.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243.** Failing set
  **member-for-member identical to the baseline**: 7 `TC_ARITY_001` smoke scripts, the
  sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture. Stable
  across B4, C1, C3, C5, C4, D1, D2 and now D3.
- **`make world_state` — PASS**, five classes with two-sided pairs plus the two provenance assertions.
- **`make discovery` — PASS**, 11 driver env keys re-derived from three source files.
- **`make strict_replay` — PASS**, both scenarios with their own measured resolution counts.
- **`make compaction_dst` — PASS**, and the target no longer needs `MOTOKO_MODELS_FILE` in its recipe.
- **`make program_persistence`, `make run_report` — PASS** after their env fixtures grew to 11 keys.
- **`make anchors` — 10/10**, after a four-consumer cascade.
- **`make driver_only`, `make profile_definition`, `make attribution_table` — PASS** at v9.
- **`make ledger_parity`, `make stream_parity`, `make invariants`, `make event_vocabulary`,
  `make terminal_trace` — PASS**, unaffected.

### TWO TARGETS ARE RED AND THIS ITEM DID NOT REPAIR THEM

**`make seeded_generator` and `make corpus_pr`**, both green at HEAD, both red here, and the cause is
one measured fact rather than two.

**Routing `context_usage` puts the driver's config reads into the RECORDED INTERACTION LOG.** Each
`resolve_context_limit` call performs five env requests, the driver makes 3 of them on the shortest
possible run and 12–19 on the suites measured above, so a recorded run carries **15 to 95 extra
interactions** that no generator authored and no scenario chose. Before this item those reads were
ambient and therefore invisible; the log is now telling the truth about a driver that re-resolves a
static configuration value on every loop arm.

What that breaks, precisely:

- `seeded_generator`'s bounded-run check is `List.length(run.world.log) <= 3 * max_interactions`. With
  `max_interactions` 6 the budget is 18 and the log is **24**. **The `3 *` was already absorbing the
  driver's fixed per-run interaction overhead** — the check compares a GENERATOR budget against a log
  the DRIVER also writes into, and this item widened the driver's share until the slack ran out.
- the `rich` fixture's S7 obligations, which read shape counts off the same log:
  `env_missing=50` now dominates the distinctness set.
- `corpus_pr`'s WI-A15 commit gate, downstream of the same corpus.

**Two repairs are available and I took neither, deliberately.**

1. **Raise the slack.** One character, and it is the wrong answer: it papers over a conflation the
   change exposed rather than fixing it, and the honest version — count only generator-authored
   interactions, or state the driver's fixed overhead as a named measured constant — is a fidelity fix
   to the check that deserves its own verification.
2. **Stop re-resolving.** `session_policy_init` already resolves the limit and stores it at
   `policy.step.compaction.context_limit`; the four `c2_loop` sites recompute it. Reading the policy
   instead would take a run's resolutions from 12–19 to one, which removes the log inflation at its
   source and removes redundant work the driver has no reason to do.

**The second is measured, not proposed on intuition.** A temporary assertion at the `CallModel` site
comparing `policy.step.model` against `model` and `policy.step.compaction.context_limit` against the
freshly resolved value reported **ZERO mismatches across `world_state`, `discovery`, `strict_replay`
and `compaction_dst`**. So the substitution is safe at that site on every scenario those four suites
run, and the same measurement is owed at the other three before it is taken.

**It is not taken here because it is a change to the driver's call pattern, not to its hermeticity.**
This item's remit was the world class and row 10, both of which are complete; a behavioural refactor
landed at the end of a long session, without its own assertion landed first (S1), is how this project
ships the silent defect it counts. **Recommended as the next item's first move**, before the
acceptance-table re-run, because it changes the env census numbers this item just pinned.

## Corrections owed to the plan

1. **S16 EXTENDS TO A CHECK'S COMPLEMENT: a strong out-of-process gate can be silent on the property
   its subject exists to provide.** C3's form is a check whose two sides share a producer; D2's is two
   artifacts pinned against each other; D3's is a check with **no shared producer at all** — the
   interpreter kills the run, nothing in the tree participates — that is nonetheless green over a
   world the driver never reads. Suggested extension: *"a gate that establishes what a run does NOT do
   says nothing about what it DOES. Poison pairs and provenance assertions are complements, and
   closing a row on one of them is closing half of it."*
2. **A SOURCE-DERIVED GATE HAS ITS OWN HAND-MAINTAINED INPUT, and that input is the stale literal the
   gate cannot see.** `make discovery` re-derives `driver_env_keys()` from the source rather than
   trusting it — and the FILE LIST it derives from is a literal nobody re-derives. It failed loudly
   here, which is luck of direction rather than design. Suggested extension: *"when a gate derives a
   claim from source, ask what tells it WHICH source."*
3. **A per-run literal must be per-SCENARIO until measured otherwise.** WI-D3 wrote one constant for
   two suites; it was right for three scenarios and wrong for two, and the second suite said so
   immediately. The general form: a quantity that varies with control flow gets a parameter on the
   first use, not on the second.
4. **The plan still has no item after Milestone C.** C4's planning defect 1 stands. The work list is
   now down to **one** entry — the `on_budget_plan` ABI change — plus the acceptance-table re-run that
   C4's item exists to schedule. Neither is in the plan.

## Out of scope, unchanged and still owed

- **Re-running C4's acceptance table and adopting the name.** The next item, deliberately not this one.
- **The `on_budget_plan` ABI change**, and `ScratchpadResult`'s and `SessionSuspend`'s coverage.
- **The two sibling `st.world_state` finalize sites** — they take `st_ctx` now so this item does not
  widen them, and they still ignore `chain.next_state`.
- **File reads in the interaction log** — see decision 6, with the measurement and the change named.
- **`FS` in `driver_only.forbidden_capabilities`** — see decision 9.
- **D4's provider latency pair**; **the adversarial partial stream**; the `motoko-ext-abi` major; the
  `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.

## THE NAME

**C4's acceptance table is GREEN: eleven of eleven.** That has not been true before in this project.

**IT DOES NOT ADOPT THE NAME, AND THIS ITEM DOES NOT.** D10 has **two** conditions:

1. **the acceptance test passes for a documented baseline profile** — the table is green as of this
   item, but **re-running it is a separate act**, which is exactly why C4's item exists;
2. **the project-007 definition/taxonomy ADR is accepted** — **checked: `Accepted 2026-07-26`**, so
   this condition is already satisfied and has been for some weeks.

So the outstanding condition is the gate re-run, not the ADR. **Eleven items have now declined the
name and this is the eleventh.**

**And a green gate for `driver_only` is a green gate for `driver_only`.** Two of the eleven passes
remain **VACUOUS in their installed-extension clauses** (rows 3 and 5's transfer caveat). Per D10 those
transfer to no second profile: they are earned again from scratch by any profile that installs an
extension. Row 10 closing makes the gate green; it does not make the vacuous passes non-vacuous, and
it says nothing whatever about a profile that is not this one.
