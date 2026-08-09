# 2026-08-09 Cluster 53: WI-D27 — the compose-bearing profile, and the goal line's clause 1

## Context

Branch: `arniwesth/mot-88-wi-d26-route-composes-exec-sites`.

Session span: `52ed505` → working tree, **committed after the session by the review role** as
`742af22` (*"docs(009): apply D27 — clause 1 achieved, profile-rules/3 ratified, one item left"*).
Input was `HANDOFF-execute-d27-the-compose-bearing-profile.md`, grounded against HEAD `52ed505`,
clean tree. Pin **v0.33.0**.

**Item 5 of the goal line's six-item critical path — the demonstration every report since D19 has
named as its debt.** 9 files from this session (3 new code/tool files, 1 new NOTE, 5 modified);
the apply commit adds 2 review-side files on top:

```text
scripts/dst/driver_plus_compose_dst.ail               1198 +  the acceptance script AND the graded
                                                              session (new)
src/core/dst_driver_plus_compose.ail                   847 +  the third profile record (new)
.agent/.../NOTE-d27-the-compose-bearing-profile.md     484 +  the record (new)
tools/profile_definition/check_compose_profile.py      418 +  the anti-transcription guard, 7 checks
                                                              (new)
src/core/dst_profile.ail                                67 +- `discovery` admitted; profile-rules /3
                                                         -2
tools/predicate-anchors/anchors.sh                      57 +- the cascade width, nine files -> eleven
                                                         -2
Makefile                                                50 +- driver_plus_compose target + sweep entry
                                                         -1
tools/profile_definition/check_fixtures.py              17 +- check_abi_version's subject list becomes
                                                          -4   a derivation
scripts/dst/profile_definition_dst.ail                   7 +- the pinned rules literal -> /3
                                                         -1
```

## The headline — the profile could not be issued under the rules as they stood

Not "was hard to issue". **Could not.** The chain is forced at every link:

- D5 requires every installed extension to account for all eight ABI slots as covered-or-excluded,
  and forbids excluding any of the seven dispatched **unconditionally**.
- Three of those seven declare a non-empty ABI effect row, so criterion 1 fails on the declared row
  and they must be covered under **criterion 2**.
- `world_mediated_is_measured` (WI-D14) refuses criterion 2 on any **Assumed** basis, and Amendment
  A's fail-closed default (`ADR:1548`) names classifier 3 as the producer that must supply it.
- Classifier 3, measured at the bound revision: `compose -- 8 ambient source(s), 36 ExtPorts field
  call(s) in closure   verdict: AMBIENT`.

And the 8 are **exactly the three classes the goal line closes by disclosure** — four `println`,
registration's three, one ambient AI. So **classifier 3 can never clear compose, no matter what
Route B routes**, because it is a closure-wide static question and the residue is disclosed rather
than routable. Under the rules as they stood, goal-line clause 1 was unreachable **by construction
rather than by measurement** — the one shape the whole D-wave exists to refuse.

**The goal line had already decided the answer and nobody had built it:** *"the evidence comes from
the discovery and witness instruments over the recorded run — a dynamic fact, not a classifier
verdict, so door 3 does not block it."*

So the item's central change is **not the profile**. It is one entry in `recognised_producers`:

| | |
|---|---|
| id | `discovery` |
| kind | `Measured` — **the first dynamic producer, and the first addition since WI-D13 closed the set** |
| target behind it | `.PHONY: discovery`; `check_recognised_producers` re-derives it and now prints **4 measured** |
| measures | an `ExtensionEffect` interaction EXISTS (only the `ExtPorts` recording adapter writes that class, so an ambient call leaves none); its `identity_origin` is the performer's id, stamped by the fold in `ext/runtime.ail`; the program STRICTLY REPLAYS |
| cannot do | **existential, not universal.** It witnesses what a run performed; it cannot bound what a hook could perform on inputs the run did not supply. It does not supersede or weaken classifier 3 |

**The fail-open shape this creates is closed twice**, deliberately: the catalogue note says the basis
is admissible only for a profile whose acceptance script asserts the run, and
`check_compose_profile.py` check 5 **fails if the run's `CLAIM clause1` line is absent** — in those
words.

`profile_rules_version` **`/2` → `/3`**, and the direction is the opposite of every previous bump:
this one **widens**. A definition clean under /2 is clean under /3; the converse does not hold, which
is exactly what the version records. The literal at `profile_definition_dst.ail:198` made the bump
non-optional — the widening was written first and that fixture went red on the version before any
profile consumed the new basis.

## The second finding, unpredicted anywhere: the first non-empty exclusion

Writing the record honestly forced it. Compose's `on_tool_handle` reaches `callStreamResult` —
ambient AI — before anything routed (D26 §5.1), so covering it would claim criterion 2 over a chain
whose **first** effect is ambient. It is the ONE `Gated` slot in the ABI, so it is the one slot a
conformant profile may exclude.

D5's disclosure mechanism has existed since WI-A6 and been non-vacuous since WI-D14, and **until this
file no profile had ever put an id in `excluded`**. Three rules were therefore quantifying over an
empty list and are live for the first time: `unconditional-hook-excluded`,
`classification-disagrees-with-disclosure`, and `routing_violation_at`. That is a vacuity one level
*below* the empty install list S21 counts, and nothing had named it.

**Conditional per S25:** the exclusion is honest only while no run under this profile dispatches a
tool compose provides. The graded session drives prose steps and dispatches none — `expect_tool=0` is
a claim, not an accident.

## The record: three kinds of entry, and the first non-zero mediation count

`driver_plus_compose` **v1**, installing **compose alone** (the four zero-barrier extensions are
declined by decision: the claim is a **ratio**, and installing 32 no-op slots would move
`world_mediating_hooks` from 1 of 7 to 1 of 39 without adding one mediated effect).

| slot | classification | basis | ports / origin / world_state |
|---|---|---|---|
| 4 rowless | `EffectFree` | `declared_row` (Assumed) | n/a |
| `on_pre_step`, `on_solver_candidate` | `WorldMediated` | **`discovery`** | Vacuously / Vacuously / Substantively |
| **`on_response_intercept`** | `WorldMediated` | **`discovery`** | **Substantively ×3** |
| `on_tool_handle` (gated) | **`ExplicitlyExcluded`** | `disclosure` | n/a |

The two vacuous entries are not a hedge — compose binds `PassThrough` and `NoDecision`, each
returning `next_state: ctx.world` (`compose.ail:1109-1126`). Same shape `driver_plus_no_ops` records,
measured **dynamically** here instead of statically there.

```text
installed_extensions=1  covered_hooks=7  excluded_hooks=1
criterion_1_hooks=4  criterion_2_hooks=3  no_op_hooks=2  world_mediating_hooks=1
```

**`world_mediating_hooks = 1` is the first non-zero this project has computed**, so
`coverage_statement` takes its **third branch for the first time** — a branch live since WI-D14 and
never reached:

> extension-model coverage is NON-ZERO: 7 hook(s) covered across 1 installed extension(s), of which
> 1 mediate the world SUBSTANTIVELY through a D1 port and 2 satisfy criterion 2 vacuously.

One is a small number and it is not rounded up. The module test asserts `== 1` **exactly** rather
than `> 0`, so a future edit that quietly promoted a vacuous entry moves it.

**Every ground moved, and three of the four re-earned rows changed argument:**
row 4's `extension_effect_fault` waiver now rests on a per-**field** fact (the class is delivered by
`ExtPorts.ai_step`; compose's only provider path is ambient and behind the excluded slot) and *would
fail the moment this profile covered `on_tool_handle` or installed `compaction_ai`*; row 5 is
re-earned **on routing instead of on absence**, since `driver_plus_no_ops`'s sentence "no installed
extension reads a clock" is FALSE here; row 7 loses **both** of its predecessor's grounds — compose's
`provided_tools` is not empty and its `on_tool_handle` does not delegate.

## The demonstration — clause 1, run rather than described

A full graded session through `run_v2_session_traced` — the real traced driver — with compose
installed through `register_with_config` from `compose.ail` (S14: our closure, not a replica).
**This is the first profile acceptance script in the project that RUNS its subject** rather than
only reading its record, and that is forced: `discovery`'s evidence *is* a run.

Subject is `on_response_intercept`, not `handle_compose_tool`, and **the record and the run agree
about why** — the same measurement the record acts on by excluding the slot. Neither is inferred
from the other.

Quantities S7-distinct from every queue constant in the tree (D26's compose fixtures use 43/47/53/59
and codes 71/73/1; driver tools -1; D24's effects 41…61): durations **79/83**, typed codes **89**
served and **97** unconsumed slack. The slack is load-bearing — an empty `ext_effects` queue
**delegates**, so a fixture sized exactly to its expectation puts a live `ailang check` inside a
deterministic gate.

Census: `expect_provider=2 expect_tool=0 expect_approval=0 expect_extension_effect=1
environment_read=10 advance_clock=4 file_write=1 file_remove=1 dir_make=1`.

Twelve rows green — terminator, **reachability before verdict** (S24), the non-vacuity row, the
failure branch on the typed code, the diagnostic surviving the decode, **`check_discovery` grading
the run clean in both directions**, VALIDATES, `reconstitution_balance` (nothing unconsumed, nothing
missing), the reconstituted queue serving 89, REPLAYS identically, the replay reproducing the
origin-tagged effect, and the replay's branch:

```text
CLAIM clause1 extension_effects=1 origins=[compose] replayed=1 mismatches=0
```

**The producer the record names is the producer the run executes.** That is what makes `discovery` a
basis here rather than a label.

**Two env facts had to be measured, not inherited.** The witness's resolution count is **1** — not
D3's 12 or strict replay's 19/8 — because an `InterceptHandled` arm appends a message and loops
without re-resolving a context limit. And `MOTOKO_TOOL_TIMEOUT_MS` is declared at **0** rather than
omitted, which is a real assertion: omitting it would let a stray dispatch's read pass unnoticed.
Five once-per-run keys + five resolution reads + zero = ten, the census exactly.

## The mutants — 2 applied, restore by file copy (S17), both restored byte-clean

**Mutant A — compose removed from the run's install list** (`compose_rt()`'s registry → `{ hooks:
[] }`; named as the run's list, since the record's `installed_extension_ids()` is a separate
mechanism and mutating it would not have changed the session). Killed **eight** rows, and the one
that matters names what vanished:

```text
✗ NON-VACUITY: … origins=[] … there is no origin-tagged extension effect in the program at all
✗ the reconstituted ext_effects queue is EMPTY, so a replay would run a real `ailang check`
```

Four classes fell to zero at once and `expect_provider` fell 2 → 1 — with no intercept there is no
second step. That is what "the demonstration did not happen" looks like.

**Mutant B — the check served the WRONG queue entry** (the two `ext_effects` entries swapped; WI-D24's
M3 shape at session level, constructible here without spawning a subprocess).

```text
✓ NON-VACUITY: … ORIGIN-TAGGED to compose          <- stayed GREEN
✗ the served content reached the model: …
✗ … head exit_code=97 — expected 89
```

**The pair working as designed:** an origin-tagged effect still happened, and the origin row
structurally **cannot** see what was served. S33's mechanism — two independent pieces of evidence,
neither substituting for the other. The branch row also stayed green, because 97 is non-zero and
compose still failed the check; only the CONTENT rows can see this defect.

## The cascade — S18's prediction, and the guard that would have been missed

S18's extension recorded it in advance: *"a third profile extends the list again with nothing naming
it in advance."* Ten consumers joined, each derived from its producer rather than remembered.

**The one that would have been missed is `check_abi_version`.** Its subject list was a hand-written
four-path list. Adding two entries would have been correct today and silently wrong at the fourth
profile — the exact defect that guard was written to catch (`driver_only`'s `4.0` stale for eleven
items, *"and nothing noticed"*). The gate red-flags `seen == 0` but **cannot see a file missing from
the list**. It is now a glob derivation over `src/core/dst_driver*.ail` and
`scripts/dst/driver_*_dst.ail`, with a floor check if the glob stops matching the convention:
**6 sites across 4 files → 10 sites across 6 files**.

**The anchor cascade went nine files → eleven with no anchor moving at all**, which is a shape none
of D21/D24/D25's three measurements covers — the width is the set of files that *pin* the anchors, so
adding a pinning file widens it. Both greps were run: the record-form one finds the new script's 2
pins; the wider string-form one reports **5**, and the other three are prose citations of
`session.ail:1417`, `session.ail:939`, `tool_phase.ail:343` — the env-read sites the witness derives
from. They cost a comment re-tense, not a re-issue, and `anchors.sh` now says which of the five are
load-bearing so the next item does not re-decide it.

`anchors.sh`'s failure message now names **three** profile versions instead of one.

## What granting `Env` and `FS` across registration exposed: nothing new

`register.ail:9` reads `getEnvOr("MOTOKO_PROFILE_DIR", ".")`, then `config.ail` reads `fileExists`
and `readFile`, all before any hook is dispatched. Capabilities are per **process**, so the run
grants both and **`make world_state`'s poison pairs say nothing about compose's registration**. The
gap is stated, not closed. What carries the determinism claim instead is the **record → strict-replay
identity** — a registration read that varied with the host would make the two runs diverge.

`FS` is a **new capability entry**; neither predecessor lists it, because neither installed anything
that reads a file. The split is exact: registration ambient and disclosed, hook paths mediated and
recorded.

The guard compares the three `DISCLOSED registration` lines against classifier 3's own ambient-source
list **in both directions** and finds them equal, so the handoff's third stop-condition did not fire
and the inventory's 15/15 claim is unaffected. The fourth did not fire either: `MOTOKO_PROFILE_DIR`
resolves to its default and no config file is present, so there is no config-conditional effect path.

**Two handoff corrections, both small, both recorded so the closing note does not inherit them:**

1. The handoff said registration's three sources are disclosed *"through the existing D5-field-9
   mechanism (`disclosures_of`)"*. They are not and cannot be — `DisclosureIds` carries
   `extension_id`, `covered`, `excluded`: **hook ids only**. They land in D5 field 6's instruments
   (where `driver_plus_no_ops` already put the same gap) and in the script's `DISCLOSED` lines. Field
   9 *is* used non-vacuously by this profile for the first time — for the **excluded hook**.
2. The handoff's DoD names the yields as *"(5/15, 4/15, 4/15)"*. The third is not 4/15:
   `ext_hook_scope`'s second yield is **HOOK-AMBIENT 2 of 15**, and the 4-of-15 appearing twice is
   classifier 3's PORT-MEDIATED yield printed by two instruments. The measured triple is **5/15,
   2/15, 4/15**; all unmoved, only the label was wrong.

## Verdicts, counters and sweep

**No counter moves** — this item assembles evidence; nothing authored-and-closed. The handoff
predicted exactly that.

Unmoved and re-measured rather than assumed: classifier 3 compose **8 sources / 36 field calls,
AMBIENT**; PORT-MEDIATED **4/15**; HOOK-PORT-MEDIATED **5/15**, HOOK-AMBIENT **2/15**; barriers
**33 of 45 pairs stand, all 3 for compose**; `driver_only` **v22** and `driver_plus_no_ops` **v9**
not re-issued; `declared_vs_performed` **46/0**.

No type touched, so `sync_packages` was not run (D22's condition): the two `src/core` edits are a
list entry and a string constant.

Green by run: `driver_plus_compose`, `driver_only`, `driver_plus_no_ops`, `profile_definition`,
`profile_coverage`, `anchors`, `predicate_anchors`, `ext_ambient_inventory`. Full `make dst`: **20
targets PASS and exactly two fail — `test_coverage` and `test_coverage_selftest`, both pinned since
D22 — and nothing new.** `effect_inventory_selftest` is not in the aggregate; run separately, it is
unchanged (`agree=0 disagree=0`, the gate correctly refusing a pass-shaped absence, pinned D25).

## What item 6 (the final acceptance rerun) inherits

The closing note is D5's shape plus two computed outputs — S21's vacuity register and the 15-row
classification table. **This item decided how much of that can be computed, and named the exact
machine-readable places:**

1. **`CLAIM clause1`** — the compose row of the vacuity register, already parsed by
   `check_compose_profile.check_the_demonstration`.
2. **`CLASSIFICATION <ext> <hook> <kind> <producer> <basis_kind> <ports> <origin_tag> <world_state>`**
   — nine fields, identical across all three acceptance scripts. **The register's per-clause counts
   are a fold over these lines and need no new instrument.**
3. **`STATEMENT`** — `coverage_statement`'s computed sentence; the three branches are
   text-distinguishable.
4. **`derive.py --json`** — per extension `verdict`, `ambient[]` (`{file, line, symbol, effects,
   why}`), `ext_ports_calls`. Every "disclosed with a measured reason" cell is one `ambient` entry
   plus its class.
5. **`DISCLOSED <kind> <ext> <cap> <file> <symbol>`** — introduced here for registration; the rerun
   will want the same shape for the `println` and AI classes.

**And what it must decide rather than compute:** the register does not shrink to zero and was never
meant to (the goal line renounced that); **`discovery` is existential and the table must say so** —
a cell reading "mediated" for compose without the qualifier is the overclaim this item was built to
avoid; twelve extensions have no profile and no dynamic evidence, so their rows still close by
disclosure and measurement; and the `on_tool_handle` exclusion is a decision with a condition.

**Priced but not scheduled:** `compaction_ai` is now the extension most likely to be installable in
the next profile of this kind — its `on_pre_step` reaches `ExtPorts.ai_step`, and a graded run
against a scripted provider would produce exactly the evidence `discovery` reads. D7/D8 measured that
the barrier there is the declared row's **vocabulary**, and a dynamic producer does not read declared
rows. The profile's own omission reason says so, so the possibility is not rediscovered as a surprise.
Maintenance register, not a goal-line blocker: clause 1 asks for *a* profile, and this is it.

**Owed, unchanged:** door 3 closes by disclosure plus an upstream filing; the registration-effects
amendment stays DRAFT; the fault catalogue's `driver_only`-naming condition now has **three**
consumers instead of two.
