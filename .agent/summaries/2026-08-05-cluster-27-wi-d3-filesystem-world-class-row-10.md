# 2026-08-05 Cluster 27: WI-D3 — the filesystem world class, and the last red row

> **CORRECTED AT REVIEW, and the correction is on the headline.** A reviewing session
> (`54abc1b`) found a THIRD red target this session did not report — `make smoke_parity` — and a
> counterexample to a basis this report stated. Both are recorded in place below rather than edited
> away. **Row 10's own producer is green; C4's TABLE was NOT green at HEAD `14ba6f9`**, because
> `corpus_pr` is rows 4 and 11's producer and it aborts before printing their evidence. `smoke_parity`
> is repaired in a follow-up commit; `corpus_pr` and `seeded_generator` are not.

## Context

Branch: `arniwesth/mot-66-close-acceptance-row-10`.

Session span: `77c44d3` → **`14ba6f9`, one commit, working tree clean**. Input was
`HANDOFF-execute-d3-filesystem-world-class-row-10.md`, executed cold against HEAD. Twenty-seventh code
session of project 009, **third and last of C4's post-gate work list**. Pin **v0.33.0**.

**Window: ~2h20m**, `17:45Z` → `20:05Z`. Roughly three times WI-D2's, and the overrun is not in the
production change — `Ports` gains a seam, `WorldState` gains a table, one module gains two parameters.
It is in the CASCADE: routing a function the driver calls at eight sites moved four environment keys
into the recorded interaction log, and six separate artifacts are keyed to that log or to the driver's
env surface. Three targets went red; two are still red at the end of the session.

**Grounding was clean.** `git status` clean at `77c44d3`, branch name matched the handoff.

| Definition-of-done item | State |
|---|---|
| Host-env poison pair, both halves | **met** — and a filesystem pair too, five classes now |
| `make world_state`'s deferral note removed rather than edited | **met** — deleted, with what it deferred recorded |
| `resolve_context_limit` threaded at all eight call sites | **met** — the note said six; it is eight |
| Row 10 re-answered against the ADR, RNG left as-is | **met** — all four clauses answered by name |
| S16: say which producer each half comes from | **met** — both halves out of process |
| S15: reasons as MEASUREMENTS; structural reasons name what must change | **met** |
| S18: tense comments BEFORE deriving anchors | **met** — cascade paid **once** |
| S13 whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1` | **met** — 226/17 of 243, failing set identical to baseline |
| S9: every live cache cleared, `~/.ailang/cache/registry` untouched | **met** |
| S17: mutation loops restore by `cp` | **met** — four mutants, each verified byte-identical after restore |
| Green table is not an adopted name, D10's two conditions named | **met** — and the table is not green either |

## THE ANSWER

**Acceptance row 10's own producer is GREEN — `make world_state` enforces five two-sided poison pairs.
The TABLE is not green at `14ba6f9`, and this report originally claimed it was.**

**The claim was wrong for a reason worth stating exactly:** a row is only as green as the target that
produces its evidence, and this item turned `corpus_pr` red. `corpus_pr` is rows 4 and 11's producer;
it aborts at the WI-A15 commit gate before printing `every expected class was OBSERVED`, so those two
rows have no passing producer. **They were green at D2 and this item took them away.** Counting row 10
as closed and then adding up the other ten from a previous item's output is exactly the
stale-number-quoted-forward class this project has carried five items running — committed here by the
item that had just finished writing about it.

**The name is not adopted, and that conclusion is unchanged** — it never rested on the table being
green, and D10's gate re-run has not happened.

| | before | after |
|---|---|---|
| Effect classes with a two-sided poison pair | 3 | **5** (+ host-env, + filesystem) |
| `resolve_context_limit` sites reading the host | 8 | **0** |
| `Ports` seams | 5 | **6** |
| `driver_env_keys()` | 7 | **11** |
| C4's acceptance rows holding | 10 of 11 | **10 of 11** — row 10 gained, rows 4 and 11 lost their producer |

## The finding: the poison pair is blind to the thing the world is for

**MEASURED, and it is the item's central result.** Bind `scripted_file` so it ignores
`WorldState.files` entirely — `lookup_file([], path)` — and **all four halves of the new pair stay
green**:

```
deterministic, Env withheld: exit=0     live, Env withheld: exit=1
deterministic, FS  withheld: exit=0     live, FS  withheld: exit=1
```

The deterministic runs still perform no ambient read; the live runs still die on `ambient_file`.

**A poison pair is a statement about what a run does NOT read. It is silent on whether the world is
read at all.** Those are different properties and only the first is hermeticity. C4 ruled that
provenance is not hermeticity; the converse holds just as strictly, and neither assertion replaces the
other. The class therefore carries a provenance assertion beside the pair — the world seeds a profile
`agent.context_limit` of 1 at the path the driver COMPUTES, the run compacts and exhausts, and a
control with no file resolves to 0 and reaches its terminator. That assertion is red on the mutant
while every pair row is green.

**This is S16 in a new shape.** C3's form is a check whose two sides share a producer; D2's is two
artifacts pinned against each other. D3's has **no shared producer at all** — the interpreter kills the
run, nothing in the tree participates — and is nonetheless green over a world the driver never reads.
The strength of a gate says nothing about its coverage.

## What was measured before anything was designed

Three measurements, taken at HEAD, before a line of production code moved.

1. **`resolve_context_limit` is the SOLE cause.** Withholding either capability killed the
   deterministic run; short-circuiting that one function — signature unchanged, so no cascade — made
   **both** withheld runs pass. That is the handoff's first stop-and-report condition, closed by
   measurement rather than by reading.
2. **AILANG gates on PERFORMED, not DECLARED.** The probe dispatches seeded tools through `world_tool`,
   which **declares** `! {IO, Process, FS}`, and completes with `FS` withheld. The declared row says
   the opposite, and the whole pair rests on the interpreter's behaviour rather than the row's.
3. **The deterministic runs were reading host files today** — and this session UNDER-COUNTED which
   ones, which is the item's own worst finding. The report said *"the DST fixtures did not depend on
   the VALUES — their models are absent from the catalogue"*. **`test/tiny` is in the catalogue, at
   100**, and `scripts/smoke_v2_compaction_full_loop.ail` drives the SCRIPTED world on it through
   `run_v2_with_scripted_ports`. Its whole fixture is the header's "100 tokens = ~400 chars"
   arithmetic. I saw `test/tiny` early in the session, reasoned that that script "runs the live-ish
   path", and never checked — it does not. **The claim held for the fixtures checked and there was a
   fixture that was not checked.** Also true, and separately:
   one suite was reading the PROCESS
   ENVIRONMENT: `compaction_dst`'s recipe set `MOTOKO_MODELS_FILE` to a fixture catalogue and
   `context_usage` read both the variable and the file ambiently, so `long_qwen_compaction_dst`'s
   context limit was a property of how the target was INVOKED. Both halves were load-bearing — with
   the world serving neither, two scenarios stop reaching their invariants. The world declares both
   now and **the recipe no longer sets the variable**.

## The C1b defect, reproduced and caught twice

The handoff named the one way this item could ship something worse than it replaced: route the env
half, leave the file half ambient, and pass an Env poison probe while still reading a host file.
Written as a mutant, and caught by **two independent routes** — a genuine
`effect 'FS' requires capability` death on the deterministic run, and the provenance assertion going
red with `finish=stop` for both the seeded and the unseeded world.

## Mutation results — four, and two are the argument

Restored by `cp` throughout (S17); every file verified byte-identical after each.

| # | Mutant | Result |
|---|---|---|
| M1 | `live_ports` binds `scripted_file` | FS-withheld LIVE run **COMPLETES** — pins the death to `ambient_file` |
| M2 | env half routed, file half ambient (C1b) | RED twice, by independent routes |
| M3 | `scripted_file` ignores `WorldState.files` | **ALL FOUR PAIR HALVES GREEN**; only the provenance assertion red |
| M4 | resolution count 12 → 11 | RED, 4 findings per scenario — the census literal is load-bearing |

## The instrument correcting the author, twice, inside the session

**The env census literal.** Each resolution performs five env requests, so the count needs the number
of resolutions a scenario reaches. I wrote it as a shared constant of 12 — correct for discovery's
three scenarios, 60 = 12 × 5 on each — and **strict replay rejected it on the next run**: `rich`
reaches 19, `maxsteps` 8. It is now a per-scenario parameter.

**No formula was fitted.** 12 at provider=4, 19 at provider=5, 8 at provider=1 do not determine a rule,
and deriving the count from the log would put both sides of the check on one producer.

**The discovery derivation's FILE LIST.** `make discovery` re-derives `driver_env_keys()` from source
rather than trusting it — and the list of files it greps is itself a literal nobody re-derives. It read
two files, the driver's env surface had moved into a third, and the derived set came back four keys
short. **It failed loudly**, which is luck of direction rather than design.

## Sites where two answers type-checked and one was silently wrong

**This item wrote production code and authored none in the tree.** Every alternative that type-checked
was caught by a gate that predates it (S1) or by the compiler.

**One is counted, in the INSTRUMENT — D2's precedent exactly. The counter is 54**, from 53.
`make world_state` was **completely green, five classes, both halves each**, before the provenance
assertion existed. That gate type-checks, passes, and is green over M3. Never shipped, but it is the
gate "row 10 is closed" would have rested on had the item stopped when the pairs went green — which
they did.

**Determinism has still caught none of the fifty-four.**

Not counted: the shared resolution literal was wrong and type-checked, but went red on the next run of
an assertion that predates it. That is S1 working, not a silent site.

## Stale reasons and prose: TEN sites, where the handoff named ONE

| # | Site | Claim that expired |
|---|---|---|
| 1 | `Makefile` `world_state` header | the env-class deferral note — **deleted, not edited** |
| 2 | the same note | "the driver calls at **six** sites" — it is eight |
| 3 | `dst_driver_only` forbidden capabilities | the `Env` row's "PROVENANCE ONLY … pair is deferred" |
| 4 | `session.ail` policy-init header | "Four of the driver's **seven** env reads" |
| 5 | `session.ail` capture-payload site | "the **sixth and last** driver env read" |
| 6 | `dst_discovery` header | the derivation greps "session.ail and tool_phase.ail" — three files now |
| 7 | `dst_profile_coverage` | `stub_step.ail:133` — **stale AT HEAD** since WI-A16, checked by nothing |
| 8 | `ports.ail` `log` field | "the **four** deterministic seams" — five |
| 9 | `ports.ail` `gen` field | "The **four** deterministic seams and the four recording ones" — five |
| 10 | `Makefile` `compaction_dst` recipe | `MOTOKO_MODELS_FILE=…` — the world declares it now |

**Sites 8 and 9 are the shape worth naming.** Every `WorldState` literal but `empty_world_state()` uses
record update, which is exactly why adding a field cost nothing — and exactly why two comments counting
the seams went stale unnoticed. **The mechanism that makes the change safe is the mechanism that makes
the prose rot.**

**Sites 4, 5, 8 and 9 are all COUNTS restated beside a derivation that already computes them.** Site 4
now names `driver_env_keys()` instead of repeating its answer — fifth consecutive item to carry this
class and the first to REMOVE a copy rather than update it.

**Two historical records were deliberately NOT rewritten** — `dst_driver_only`'s v7 and v8 cascade notes
both say `stub_step.ail:202` and both are records of what was true at WI-C5 and WI-D2. S15's trap
exactly.

## The anchor cascade, paid once — and a fourth consumer

**Three anchors moved:** `stub_step.ail` 202 → 203, `session.ail` 2601 → 2654 and 2711 → 2764.
`session.ail` 881/1126/1232, `tool_phase.ail` 313/314/373 and `ext/runtime.ail:190` did not.

**No judgement was available** — one candidate each, the same answer B4, C1, C3, C5 and D2 got. The
claim did not change: same seven sites, still 6 routed of 7. WI-D3 adds no clock site; its new ambient
reader is `ambient_file`, and that table is the CLOCK attribution.

`driver_only` re-issued **v8 → v9**, content hash re-recorded. **A FOURTH consumer beyond D2's set:**
`tools/predicate-anchors/anchors.sh` carries its own copy of the line numbers, and `make anchors` kept
reporting the old ones after every `.ail` consumer was updated.

**Paid exactly once.** All nine tensed comment blocks were rewritten BEFORE any anchor was derived.

## Gate state

- **Whole-tree sweep, cache-cold: 226 pass / 17 fail of 243**, failing set **identical to baseline**.
  Stable across B4, C1, C3, C5, C4, D1, D2 and now D3.
- **PASS:** `world_state`, `discovery`, `strict_replay`, `compaction_dst`, `program_persistence`,
  `run_report`, `anchors` (10/10), `driver_only`, `profile_definition`, `attribution_table` (v9),
  `ledger_parity`, `stream_parity`, `invariants`, `event_vocabulary`, `terminal_trace`.

### THE RED SET WAS UNDER-REPORTED: THREE TARGETS, NOT TWO

**`make seeded_generator`, `make corpus_pr` and `make smoke_parity`** were all green at HEAD and all
red at `14ba6f9`. `make dst` therefore had **five** red targets, not the two this series has carried,
and its ✓ rows fell **831 → 701** — because an aborting target stops producing rows rather than
reporting failures, so the missing evidence looks like nothing at all. **S19's shape again: a check
that vanishes is indistinguishable from a check that passes.**

**How the third was missed, stated plainly because the method is the lesson.** Final verification ran a
HAND-PICKED list of fifteen targets rather than `make dst` to completion. The list was assembled from
the artifacts this item had touched, so it could only ever confirm what the author already suspected.
The full run that would have caught it was started three times and killed each time for being stale
against ongoing edits — and then never restarted before reporting. **`make world_state`, `discovery`,
`strict_replay` and `compaction_dst` all pass; the target that broke is one none of them covers, which
is S13's lesson in a new place.**

`smoke_parity` is REPAIRED in the follow-up: `scripted_ports` gains a
`run_v2_with_scripted_world` sibling and the fixture declares `test/tiny` at 100 and
`anthropic/claude-sonnet-4-6` at 200000 in its own `files` table, the same move `long_qwen` needed.
`totally-unknown-model` is deliberately left out of that table so test 4 asserts what it says rather
than passing because no catalogue was found.

**`seeded_generator` and `corpus_pr` remain red.** One cause, and a different one.

**Routing puts the driver's config reads into the RECORDED INTERACTION LOG** — 15 extra interactions on
the shortest run, up to 95 on the measured suites, because the driver re-resolves a static value on
every loop arm. Invisible while the reads were ambient. `seeded_generator`'s bound is
`log ≤ 3 × max_interactions`; **the `3 ×` was already absorbing driver overhead**, and this widened the
driver's share until the slack ran out — the check compares a GENERATOR budget against a log the
DRIVER also writes into.

**Two repairs, neither taken.**

1. Raise the slack. One character, and wrong: it papers over the conflation the change exposed.
2. Stop re-resolving — `session_policy_init` already stores the limit at
   `policy.step.compaction.context_limit`, and the four `c2_loop` sites recompute it. **Measured safe:**
   a temporary assertion comparing `policy.step.model` and the stored limit against the freshly
   resolved value reported **ZERO mismatches** across four suites.

**Not taken because it is a change to the driver's CALL PATTERN, not its hermeticity.** The remit was
the world class and row 10, both complete. A behavioural refactor landed at the end of a long session
without its assertion first (S1) is how this project ships the defect it counts. **Recommended as the
next item's first move**, before the acceptance-table re-run, because it changes the census numbers
this item pinned.

## Corrections owed to the plan

1. **S16 extends to a check's COMPLEMENT.** A gate with genuinely independent producers can be silent
   on the property its subject exists to provide. *"A gate that establishes what a run does NOT do says
   nothing about what it DOES. Poison pairs and provenance assertions are complements; closing a row on
   one of them closes half of it."*
2. **A source-derived gate has its own hand-maintained INPUT.** `make discovery` re-derives a claim from
   source and the file list it derives from is a literal nobody re-derives. *"When a gate derives a
   claim from source, ask what tells it WHICH source."*
3. **A per-run literal is per-SCENARIO until measured otherwise.** One constant for two suites was right
   for three scenarios and wrong for two.
4. **A routing change is a LOG-VOLUME change, and the plan should size it as one.** Six artifacts are
   keyed to the recorded interaction log or the driver's env surface. Two absorbed it, two needed their
   fixtures grown, two are still red. **This is a distinct cost from the anchor cascade and nothing in
   the plan predicts it.**
5. **The plan still has no item after Milestone C.** C4's planning defect 1 stands. The work list is
   down to the `on_budget_plan` ABI change, plus the acceptance-table re-run C4's item exists to
   schedule, plus the redundant-resolution repair above.

## THE NAME

**Row 10's producer is green. C4's TABLE IS NOT — rows 4 and 11 lost their producer to this item's
own regression, and the sentence "eleven of eleven" was written before `make dst` was run to
completion.**

**IT DOES NOT ADOPT THE NAME.** D10 has two conditions: the acceptance test passing for a documented
baseline profile — the table is green, but **re-running it is a separate act**, which is precisely why
C4's item exists — and the project-007 definition/taxonomy ADR being accepted, which is
**`Accepted 2026-07-26`** and has been satisfied for weeks. The outstanding condition is the gate
re-run, not the ADR.

**Eleven items have now declined the name and this is the eleventh** — and this one would have had
to decline it anyway, because the table it claimed was green was not.

And a green gate for `driver_only` is a green gate for `driver_only`. Two of the eleven passes remain
**vacuous in their installed-extension clauses** and per D10 transfer to no second profile. Row 10
closing makes the gate green; it does not make the vacuous passes non-vacuous, and it says nothing
whatever about a profile that is not this one.
