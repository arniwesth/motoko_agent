# NOTE-d27 — the compose-bearing profile: the demonstration

Item 1 of the two remaining (the plan's item 5 of six). Ground: HEAD `52ed505`
(`docs(009): WI-D27 handoff — the compose-bearing profile`), clean tree at start.

---

## 0. THE HEADLINE

**The profile the goal line asks for could not be issued under the evidentiary rules as they stood,
and the reason is structural rather than incidental: no producer in this tree can ever clear
compose, so a profile that installs it can never record a criterion-2 hook.**

D5 requires every installed extension to account for all eight ABI slots as covered-or-excluded, and
forbids excluding any of the seven that are dispatched unconditionally. Three of those seven declare
a non-empty ABI effect row, so criterion 1 fails on the declared row and they must be covered under
**criterion 2**. `world_mediated_is_measured` (WI-D14) refuses criterion 2 on any ASSUMED basis, and
Amendment A's fail-closed default names classifier 3 as the producer that must supply it. Measured
at the bound revision:

```
compose -- 8 ambient source(s), 36 ExtPorts field call(s) in closure   verdict: AMBIENT
```

and the 8 are exactly the three classes the goal line closes **by disclosure** — four `println`,
registration's three, one ambient AI. **Classifier 3 will therefore never report compose clean, no
matter what Route B routes**, because it is a closure-wide static question and the residue is
disclosed rather than routable. Under the rules as they stood, goal-line clause 1 was unreachable by
construction and not by measurement — the one shape this project's whole D-wave exists to refuse.

**The goal line had already decided the answer and nobody had built it.** Its own wording:

> The evidence comes from the discovery and witness instruments over the recorded run — **a dynamic
> fact, not a classifier verdict**, so door 3 does not block it.

So this item's central change is not the profile. It is one entry in
`recognised_producers` — `discovery`, kind `Measured`, the **first dynamic producer and the first
addition to that closed set since WI-D13 closed it** — plus the rules bump that records what
changed. Every producer before it reads SOURCE and answers universally; this one reads a **recorded,
validated, strictly-replayed run** and answers existentially. The distinction is in the catalogue
note, in the profile header, and in a guard that fails if the record ever swaps one for the other.

**The second finding is smaller and was not predicted anywhere.** Writing the record honestly forced
the project's **first non-empty `excluded` list**. Compose's `on_tool_handle` reaches
`callStreamResult` — ambient AI — before anything routed (WI-D26 §5.1), so covering it would claim
criterion 2 over a chain whose first effect is ambient. It is the ONE gated slot in the ABI, so it
is the one slot a conformant profile may exclude. D5's disclosure mechanism has existed since WI-A6
and been non-vacuous since WI-D14, and until this file **no profile had ever put an id in
`excluded`** — so `unconditional-hook-excluded`, `classification-disagrees-with-disclosure` and
`routing_violation_at` had all been quantifying over an empty list. Three rules, live for the first
time, one level below the empty install list S21 counts.

---

## 1. THE GIT WALL-CLOCK WINDOW

| | |
|---|---|
| HEAD at start | `52ed505` |
| tree at start | clean |
| files changed | 5 modified, 3 added |

**Added:** `src/core/dst_driver_plus_compose.ail`, `scripts/dst/driver_plus_compose_dst.ail`,
`tools/profile_definition/check_compose_profile.py`.
**Modified:** `src/core/dst_profile.ail` (the producer + the rules version),
`scripts/dst/profile_definition_dst.ail` (the pinned rules literal),
`tools/profile_definition/check_fixtures.py` (the ABI-version subject derivation),
`tools/predicate-anchors/anchors.sh` (the cascade width), `Makefile` (target + aggregate).

**No type was touched, so `make sync_packages` was not run** (D22's condition): the two edits to
`src/core` are a list entry and a string constant, neither of which is a package-side type.

---

## 2. THE DECISION, AND WHAT IT IS CONDITIONAL ON (S25)

`recognised_producers` gains one entry:

| | |
|---|---|
| id | `discovery` |
| kind | `Measured` |
| Makefile target behind it | `.PHONY: discovery` — re-derived by `check_recognised_producers`, which now prints **4 measured** |
| what it measures | criterion 2's three clauses over one recorded run: an `ExtensionEffect` interaction EXISTS (only the `ExtPorts` recording adapter writes that class, so an ambient call leaves none); its `identity_origin` is the performing extension's id, stamped by the fold in `ext/runtime.ail`; the program STRICTLY REPLAYS, which no chain that dropped a successor world can do |
| what it CANNOT do | it is **existential**. It witnesses effects a run performed; it cannot bound effects a hook could perform on an input the run did not supply. Classifier 3 quantifies universally over source; this one quantifies existentially over one execution. It does not supersede, replace or weaken classifier 3, and a profile resting on it claims *"this mediated, here, and the record proves it"* and never *"nothing else can happen"* |

**The fail-open risk this creates, and what closes it.** A profile could cite `discovery` and run
nothing. That is precisely the shape `basis` was added to close, one level out. Two things refuse
it: the producer's own catalogue note says the basis is admissible *only* for a profile whose
acceptance script asserts the run, and `check_compose_profile.py` check 5 **fails if the run's
`CLAIM clause1` line is absent** — the guard's message says so in those words.

`profile_rules_version` moves **`profile-rules/2` → `/3`**, and the direction is the opposite of
every previous bump: this one WIDENS what is admissible. A definition clean under /2 is clean under
/3; the converse does not hold, which is exactly what the version records. The literal in
`profile_definition_dst.ail:198` is what made the bump non-optional — the widening was written first
and that fixture went red on the version before any profile consumed the new basis.

**Neither existing profile is re-issued.** `driver_only` stays **v22** and `driver_plus_no_ops`
stays **v9**, verified by running both targets: neither names the new producer, and both build their
manifests from `profile_rules_version()` rather than from a literal.

---

## 3. THE PROFILE RECORD, FIELD BY FIELD, WITH EACH CLAIM'S CONDITION

`driver_plus_compose` **v1**, installing **compose alone**.

### 3.1 The install list is ONE extension, by decision

The four zero-barrier extensions `driver_plus_no_ops` installs are installable here and are
**declined**, with the reason in the record: the profile's claim is a **ratio**, and installing four
extensions with eight no-op slots each moves `world_mediating_hooks` from **1 of 7** to **1 of 39**
without adding one mediated effect. `check_compose_profile.check_install_set` fails if the list is
anything but `["compose"]`, and says why.

### 3.2 The eight slots, three kinds of entry — a shape no previous profile has had

| slot | rowed? | classification | basis | ports | origin | world_state |
|---|---|---|---|---|---|---|
| `on_describe_tools` | rowless | `EffectFree` | `declared_row` (Assumed) | n/a | n/a | n/a |
| `on_build_system_prompt` | rowless | `EffectFree` | `declared_row` | n/a | n/a | n/a |
| `on_budget_plan` | rowless | `EffectFree` | `declared_row` | n/a | n/a | n/a |
| `on_tool_policy` | rowless | `EffectFree` | `declared_row` | n/a | n/a | n/a |
| `on_pre_step` | rowed | `WorldMediated` | **`discovery`** (Measured) | **Vacuously** | Vacuously | Substantively |
| `on_solver_candidate` | rowed | `WorldMediated` | **`discovery`** | **Vacuously** | Vacuously | Substantively |
| **`on_response_intercept`** | rowed | `WorldMediated` | **`discovery`** | **Substantively** | **Substantively** | **Substantively** |
| `on_tool_handle` | rowed, **GATED** | **`ExplicitlyExcluded`** | `disclosure` | n/a | n/a | n/a |

The two vacuous entries are not a hedge: compose binds `on_pre_step` to `PassThrough` and
`on_solver_candidate` to `NoDecision`, each returning `next_state: ctx.world`
(`compose.ail:1109-1126`). They are dispatched on every step of the graded run and perform nothing,
so clauses 1 and 2 hold over an empty set — the same shape `driver_plus_no_ops` records, measured
**dynamically** here instead of statically there.

`coverage_substance`, computed:

```
installed_extensions=1  covered_hooks=7  excluded_hooks=1
criterion_1_hooks=4  criterion_2_hooks=3  no_op_hooks=2  world_mediating_hooks=1
```

**`world_mediating_hooks = 1` is the first non-zero this project has ever computed**, and
`coverage_statement` therefore takes its **third branch for the first time** — a branch that has
existed since WI-D14 and never been reached:

> extension-model coverage is NON-ZERO: 7 hook(s) covered across 1 installed extension(s), of which
> 1 mediate the world SUBSTANTIVELY through a D1 port and 2 satisfy criterion 2 vacuously.

One is a small number and it is not rounded up. The guard fails if the statement is the no-op or
zero-coverage sentence, and the module's own test asserts `world_mediating_hooks == 1` **exactly**
rather than `> 0`, so a future edit that quietly promoted a vacuous entry moves it.

### 3.3 Every claim, and what it is conditional on

| claim | condition, stated in the record |
|---|---|
| `on_response_intercept` mediates substantively | **on the inputs the graded run supplied.** Existential. It does not bound what the hook does on other inputs |
| `on_tool_handle` is excludable | it is the ONE `Gated` slot; re-derived from the dispatch table by the guard, which fails if the excluded slot is unconditional |
| the exclusion is honest | **only while no run under this profile dispatches a tool compose provides.** `routing_violation_at` is the runtime check; the graded session drives prose steps and dispatches no tool at all |
| `extension_effect_fault` is waived | on a per-FIELD fact: the class is delivered by `ExtPorts.ai_step`, compose's only provider path is the ambient `callStreamResult`, and that path is behind the excluded slot. **It would fail the moment this profile covered `on_tool_handle` or installed `compaction_ai`** |
| row 5, virtual time | compose DOES read a clock — through `ExtPorts.clock_now`. `driver_plus_no_ops` earned this row with *"no installed extension reads a clock"*; that sentence is FALSE here and the row is re-earned **on routing instead of on absence** |
| row 7, the `ScratchpadResult` exemption | **both** of `driver_plus_no_ops`'s grounds are unavailable — compose's `provided_tools` is not empty and its `on_tool_handle` does not delegate. Re-earned on the exclusion plus the absence of a tool named `scratchpad` |
| compose is classifier-clean | **NOT CLAIMED, anywhere.** The three barriers stand, `make profile_definition` says so on every run, door 3 is untouched |
| `Env` / `FS` | **GRANTED to this profile's runs, not withheld** — see §6 |

### 3.4 The waiver defect, now recorded by a third profile

`extension_effect_fault`'s catalogue condition names `driver_only` inside it and the machinery
requires a verbatim match, so a third profile now records a sentence about a different profile.
**Reported, not fixed**, on WI-D14's own reasoning and with the price now higher: it is a catalogue
content change with its own version bump and a ripple across three profiles.

---

## 4. THE DEMONSTRATION — clause 1, run rather than described

A full graded session through **`run_v2_session_traced`**, the real traced driver, with compose
installed through `register_with_config` from `compose.ail` — the entry point the host uses and the
one `declared_vs_performed` uses, per S14's *"our closure, not a replica"*.

**The subject is `on_response_intercept`, not `handle_compose_tool`**, and the record and the run
agree about why: compose's tool path calls `callStreamResult` before it reaches anything routed
(WI-D26 §5.1, §13.3), which is the same measurement the record acts on by EXCLUDING the slot.
Neither is inferred from the other.

### 4.1 The quantities (S7)

Distinct from every queue constant in the tree — `discovery_dst`'s compose fixtures use durations
43/47/53/59 and typed codes 71/73/1, the driver's tools use -1, WI-D24's effects use 41…61:

| | |
|---|---|
| durations | **79** (served), **83** (slack) |
| typed exit codes | **89** (served), **97** (unconsumed slack) |
| entries against dispatches | 2 against 1 |

The slack entry is load-bearing rather than defensive: an empty `ext_effects` queue does not fail,
it **delegates**, so a fixture sized exactly to its expectation turns any future off-by-one into a
live `ailang check` subprocess inside a deterministic gate. Mutant A below shows exactly that arm
firing.

### 4.2 The census, measured

```
expect_provider=2 expect_tool=0 expect_approval=0 expect_extension_effect=1
environment_read=10 runtime_random_draw=0 advance_clock=4
file_write=1 file_remove=1 dir_make=1
```

`expect_tool=0` is a claim and not an accident: `on_tool_handle` is excluded, so a dispatched tool
would be a routing violation of this profile's own disclosure, and the script cannot produce one.

### 4.3 The round trip, twelve rows, all green

```
✓ the graded session reached its terminator
✓ compose's routed seam RAN — the extension reached the recorder            (S24, before verdict)
✓ NON-VACUITY: the recorded program carries a world-mediated effect ORIGIN-TAGGED to compose
✓ compose took the FAILURE branch, on the typed exit code and not on the rendered one
✓ the served content reached the model: the diagnostic came back through the decode
✓ the DISCOVERY instrument grades the run clean in both directions
✓ the recorded program VALIDATES
✓ the reconstituted world's queues balance against the log — nothing unconsumed, nothing missing
✓ the reconstituted queue serves the same TYPED exit code the recording did
✓ the graded session REPLAYS to an identical interaction log
✓ NON-VACUITY, REPRODUCED: the replay records the same origin-tagged compose effect
✓ the REPLAY takes the same failure branch
CLAIM clause1 extension_effects=1 origins=[compose] replayed=1 mismatches=0
```

**The producer the record names is the producer the run executes.** `check_discovery` is called with
a hand-built `DiscoveryWitness`, graded in both directions against witnesses the recorder did not
write. That is what makes `discovery` a real basis here rather than a label: the profile cites the
instrument, and the instrument runs, on this run, in this gate.

**Two env facts had to be measured rather than inherited.** The witness's resolution count is **1**,
not the 12 `discovery_dst` measured or the 19/8 `strict_replay_dst` measured — two prose steps and no
tool phase reach one `resolve_context_limit`, because an `InterceptHandled` arm appends a message and
loops without re-resolving. And `MOTOKO_TOOL_TIMEOUT_MS` is declared at **0** rather than omitted,
which is a real assertion: omitting the key would let a stray dispatch's read pass unnoticed.
Five once-per-run keys + five resolution reads + zero = ten, which is the census exactly.

---

## 5. THE MUTANTS: 2 applied, each killed its named row

Save and restore by **file copy** (S17); the file was verified byte-identical after each restore and
`make driver_plus_compose` re-run green.

### Mutant A — compose removed from the run's install list

`compose_rt()`'s registry bound to `{ hooks: [] }`. **This is the run's install list, which is the
one the non-vacuity row is about** — the profile record's `installed_extension_ids()` is a separate
mechanism and mutating it would not have changed the session. Named here because the two are not the
same list and the handoff's phrase covers both.

Killed **eight** rows, and the one that matters names what vanished:

```
✗ NON-VACUITY: … — origins=[] — expected at least one, all "compose". If compose is not in
  the install list this row is what goes red, and it names what vanished: there is no
  origin-tagged extension effect in the program at all
✗ the reconstituted queue serves the same TYPED exit code the recording did — the reconstituted
  ext_effects queue is EMPTY, so a replay would run a real `ailang check`
```

census under the mutant: `expect_extension_effect=0 file_write=0 file_remove=0 dir_make=0`, and
`expect_provider` fell 2 → 1 — with no intercept there is no second step. Four classes at zero at
once is what "the demonstration did not happen" looks like.

### Mutant B — the check served the WRONG queue entry (WI-D24's M3 shape)

The two `ext_effects` entries swapped, so compose's `check_snippet` is answered by the slack entry
(exit 97, `cmd: "unreached"`, empty stderr) instead of the fixture. This is M3 at session level: M3
made `ext_effects_of` collect `ToolIdentity` so the head served was the driver's entry; here the
head served is the wrong extension-effect entry, and it is constructible in this file without
spawning a subprocess.

```
✓ NON-VACUITY: the recorded program carries a world-mediated effect ORIGIN-TAGGED to compose
✗ the served content reached the model: the diagnostic came back through the decode
✗ the reconstituted queue serves the same TYPED exit code the recording did — head exit_code=97,
  expected 89
```

**The non-vacuity row stayed GREEN and the served-content row caught it**, which is the pair working
as designed: an origin-tagged effect still happened, and the origin row structurally cannot see WHAT
was served. That is S33's mechanism — the two rows are independent evidence and neither substitutes
for the other. The branch row also stayed green, because 97 is non-zero and compose still failed the
check; only the CONTENT rows can see this defect.

---

## 6. WHAT GRANTING `Env` AND `FS` ACROSS REGISTRATION ACTUALLY EXPOSED

The measurement, and it is the reason the profile's D5 field 6 has **six** entries where both
predecessors have five:

- `register.ail:9` reads `getEnvOr("MOTOKO_PROFILE_DIR", ".")`; `config.ail` then reads `fileExists`
  and `readFile`. All three run **before any hook is dispatched**, and AILANG capabilities are per
  PROCESS, so the run grants `{Env, FS}` to the whole process.
- **`make world_state`'s poison pairs therefore say nothing about compose's registration**, and the
  profile says so in the instrument text rather than in prose beside it. The gap is stated, not
  closed.
- **What carries the determinism claim instead is the record → strict-replay identity**, which the
  acceptance script asserts: a registration read that varied with the host would make the two runs
  diverge and the replay row would go red.
- `FS` is a **new capability entry** — neither predecessor lists it, because neither installed
  anything that reads a file. The split is exact: registration ambient and disclosed, hook paths
  mediated and recorded (`dir_make` / `file_write` / `file_remove`, all recorded classes).

**Nothing new was exposed, and that is the reportable result.** The handoff's third stop-condition
was *"if the demonstration requires granting a capability whose only consumer is an UNdisclosed
ambient site"*. It does not: the guard compares the profile's three `DISCLOSED registration` lines
against classifier 3's own ambient-source list **in both directions** and finds them equal — every
disclosed source is one the instrument found, and every `{Env, FS}` source the instrument found in
compose's registration files is disclosed. The inventory's 15/15 resolution claim is unaffected.

**The handoff's fourth stop-condition also did not fire:** compose's registration behaved identically
under this profile's env/config inputs as the inventory's accounting assumes. `MOTOKO_PROFILE_DIR`
resolves to its default `"."` in the graded run and no config file is present, so
`read_compose_host_config` takes its absent branch; there is no config-conditional effect path, and
the disclosure matches what runs.

**Where the disclosure lives, and it is not where the handoff predicted.** The handoff said
registration's three sources are disclosed "through the existing D5-field-9 mechanism
(`disclosures_of`)". They are not, and cannot be: `DisclosureIds` carries `extension_id`, `covered`
and `excluded` — **hook ids only**, with no room for an ambient source. The disclosure lands in D5
field 6's `forbidden_capabilities` instruments, which is where `driver_plus_no_ops` already put the
same gap ("NAMED LIMIT: register_with_config is OUTSIDE that closure"), and in the acceptance
script's `DISCLOSED registration` lines, which is where a machine can read it. Field 9's mechanism is
used non-vacuously by this profile for the first time, but for the **excluded hook**, not for
registration.

---

## 7. THE CASCADE: joined, and each consumer's producer named

S18's extension predicted this exactly: *"a third profile extends the list again with nothing naming
it in advance."* Derived from producers, not from memory:

| # | consumer | producer that derives it | joined how | verified by |
|---|---|---|---|---|
| 1 | D4 re-issue check (attribution ref + `content_hash`) | `Attr.table_identity()` vs the profile's recorded literal | `compose_attribution_ref()` records the pair as a literal, exactly as both predecessors do — calling `table_identity()` would make the comparison a tautology | `scenario_attribution_ref_is_current` ✓ |
| 2 | the sweep's "this profile was not re-issued" guard | `validate_attribution_ref` inside `validate_definition_at_load` | the profile loads clean, so the guard has a subject | `make driver_plus_compose` ✓ |
| 3 | `anchors.sh`'s width-law grep | `grep -rn '\(session\|tool_phase\|ext/runtime\).ail", line: [0-9]' --include=*.ail .` | **VERIFIED, not assumed**: the grep finds `scripts/dst/driver_plus_compose_dst.ail` with 2 pins, in the same literal shape as its two predecessors | grep re-run; output pasted into `anchors.sh` |
| 3b | the STRING-form grep the record-form one is blind to | `grep -rn '\(session\|tool_phase\|ext/runtime\).ail[":][, ]*\(line: \)\?[0-9]'` | also run. It reports **5** hits in the new script against the record form's 2; the other three are **prose citations** of `session.ail:1417`, `session.ail:939` and `tool_phase.ail:343` — the env-read sites the witness is derived from. They cost a comment re-tense, not a re-issue, and `anchors.sh` now says which of the five are load-bearing | grep re-run; recorded at the D27 block |
| 4 | the anchor-move cascade width | the same grep | **NINE files → ELEVEN**, list re-derived and written into `anchors.sh`; the failure message now names three profile versions instead of one | `make anchors` ✓, `make predicate_anchors` ✓ |
| 5 | `check_abi_version`'s site scan | `packages/motoko-ext-abi/ailang.toml`'s `version` | the subject list was **replaced by a glob derivation** — every `src/core/dst_driver*.ail` and `scripts/dst/driver_*_dst.ail` — because the gate red-flags `seen == 0` but **cannot** see a file missing from a hand-written list | count grew **6 sites across 4 files → 10 sites across 6 files** |
| 6 | `check_recognised_producers` | the Makefile's `.PHONY` targets | `discovery` has a target; the print moved **3 measured → 4 measured** | `make profile_definition` ✓ |
| 7 | `profile_definition` fixtures | `profile_rules_version()` vs the fixture's literal | the literal moved to `profile-rules/3` | `make profile_definition` ✓ |
| 8 | `profile_coverage` fixtures | `all_hook_slots()` / the ABI | unchanged — the new profile adds no slot; its disclosure is checked by the same `validate_install_list` | `make profile_coverage` ✓ |
| 9 | the `make` aggregate | `Makefile:199` | `driver_plus_compose` added between `driver_plus_no_ops` and `fault_catalogue` | `make dst` |
| 10 | the Makefile target | — | new `.PHONY: driver_plus_compose`, with the full capability set and `--ai-stub` because it RUNS the subject | ✓ |

**The one that would have been missed.** Consumer 5 was a hand-written list of four paths. Adding two
entries to it would have been correct today and silently wrong at the fourth profile — the exact
shape of the defect that guard was written to catch (`driver_only`'s `4.0` stale for eleven items,
"and nothing noticed"). It is now derived, with a floor check that fails if the glob stops matching
the naming convention. Reported because it is a correction to a guard, not only a join.

---

## 8. THE COUNTERS AND THE YIELDS

**No counter moves.** This item assembles evidence; nothing was authored-and-closed. The handoff
predicted exactly this and it held.

Verdicts unmoved, each re-measured rather than assumed:

| | |
|---|---|
| classifier 3, compose | **8 ambient sources / 36 ExtPorts field calls**, verdict AMBIENT — unchanged |
| classifier 3 yield | PORT-MEDIATED **4 of 15**; AMBIENT **11** — unmoved (`shipped closure verdict unmoved, 4 of 15`) |
| `ext_hook_scope` yield | HOOK-PORT-MEDIATED **5 of 15**, HOOK-AMBIENT **2 of 15** — unmoved; compose still HOOK-UNRESOLVED on door 3's `show` |
| barriers, per (extension, slot) | **33 of 45 pairs stand**; zero remain for the same four extensions; **all 3 stand for compose** |
| `driver_only` | **v22**, not re-issued |
| `driver_plus_no_ops` | **v9**, not re-issued |
| `declared_vs_performed` | **46 passed, 0 failed** |
| the three standing reds | unchanged, nothing new |

**A correction to the handoff, small and worth stating so the closing note does not inherit it.** The
handoff's definition-of-done names the yields as *"(5/15, 4/15, 4/15)"*. The third figure is not
4/15: `ext_hook_scope`'s second yield is **HOOK-AMBIENT 2 of 15**, and the 4-of-15 that appears twice
is classifier 3's PORT-MEDIATED yield printed once by the inventory and once by the hook-scope
self-test's *"shipped closure verdict unmoved"* pin. The measured triple is **5/15, 2/15, 4/15**.
Every one of them is unmoved; only the label was wrong.

---

## 9. GREEN — run, not reported

Named gates, each run individually:

```
driver_plus_compose              PASS   (new)
driver_only                      PASS   v22
driver_plus_no_ops               PASS   v9
profile_definition               PASS   4 measured producers, 3 barriers stand
profile_coverage                 PASS
anchors                          PASS
predicate_anchors                PASS   6 anchors, 7 references, no drift
ext_ambient_inventory            PASS   15/15 resolved
```

```
effect_inventory_selftest        FAIL   (standing red, unchanged — see below)
```

### 9.1 The full sweep

`make dst`, logged to a file rather than piped, with no tracked file touched while it ran. **Twenty
named targets PASS, and EXACTLY TWO fail — both of them standing reds pinned to HEAD before this
item, and nothing new:**

| target | finding | pinned since |
|---|---|---|
| `test_coverage_selftest` | 2 failures — `stale_skip_record` on an unexpected subject; `named_only.ail` also fired `failing` | D22 |
| `test_coverage` | `prompts_test.ail`; `stale_skip_record` "Named test blocks not yet implemented" | D22 |

`effect_inventory_selftest` is **not** in the `dst` aggregate (`Makefile:199`); it was run separately
and is unchanged — `agree=0 disagree=0`, *"compared ZERO modules… a pass-shaped absence, not a
pass"*, the gate correctly refusing an absence, exactly as D25 recorded and D26 confirmed.

The new target appears green inside the sweep: **`driver_plus_compose_dst PASS`** at line 1847, with
the guard's eight rows behind it, and `declared_vs_performed: 46 passed, 0 failed`.

---

## 10. WHAT ITEM 2 (THE FINAL ACCEPTANCE RERUN) INHERITS

The closing note is D5's shape plus two computed outputs — S21's vacuity register and the 15-row
classification table. **This item decided how much of that can be computed, and the answer is: more
than before, from three named places.**

### 10.1 The machine-readable places to read

| what the rerun needs | where to read it | shape |
|---|---|---|
| **the vacuity register's compose row** | `make driver_plus_compose`'s `CLAIM clause1` line | `extension_effects=N origins=[…] replayed=N mismatches=N` — parse with `check_compose_profile.check_the_demonstration`, which already does it |
| **per-hook vacuity, every profile** | the `CLASSIFICATION` lines each profile's acceptance script prints | `CLASSIFICATION <ext> <hook> <kind> <producer> <basis_kind> <ports> <origin_tag> <world_state>` — nine fields, identical across all three scripts. **The register's per-clause counts are a fold over these lines and need no new instrument** |
| **the coverage substance, per profile** | the `STATEMENT` line | `coverage_statement`'s computed sentence; the three branches are distinguishable by text and `world_mediating_hooks` is in it |
| **the classification table's 15 rows** | `python3 tools/ext_ambient_inventory/derive.py --json` | per extension: `verdict`, `ambient` (a list of `{file, line, symbol, effects, why}`), `ext_ports_calls`. **Every "disclosed with a measured reason" cell is one entry of `ambient` plus the class it belongs to** |
| **which ambient sources are DISCLOSED rather than merely present** | the `DISCLOSED <kind> <ext> <cap> <file> <symbol>` lines | introduced by this item for registration. Only `driver_plus_compose` emits them today; the rerun will want the same shape for the `println` and AI classes |
| **the omission reasons, per extension** | the `OMITTED <ext>` lines + the profile's `omitted_extensions` | three distinct reasons now (`declined`, barrier, `compaction_ai`'s own) |

### 10.2 What the rerun must NOT compute, and must decide

1. **The vacuity register does not shrink to zero and was never meant to.** The goal line renounced
   that explicitly. What this item changes is that **one row leaves it with an assertion attached**:
   row 3's four installed-extension clauses now have a profile where the coverage floor, the
   exclusion rule and the disclosure are all non-vacuous, and where one covered hook mediates. The
   other three vacuity-bearing rows are untouched.

2. **`discovery` is EXISTENTIAL and the rerun must say so in the table.** A classification table cell
   reading "mediated" for compose without the qualifier would be the overclaim this whole item was
   built to avoid. The honest cell is *mediated on dynamic evidence, over a recorded run; classifier
   3 reports it AMBIENT with 8 sources in three disclosed classes*.

3. **Twelve extensions have no profile and no dynamic evidence.** `discovery` rescues only what a run
   exercises. The classification table's other fourteen rows still close by disclosure and
   measurement, exactly as clause 2 says, and this item adds no evidence for any of them.

4. **The `on_tool_handle` exclusion is a decision with a condition** (§3.3). If the rerun's table
   claims compose's tool path is anything, it must say the profile excluded it and why.

### 10.3 The one thing worth building next, priced

**`compaction_ai` is now the extension most likely to be installable in the next profile of this
kind**, and the profile's own omission reason says so rather than leaving it to be rediscovered: its
`on_pre_step` reaches `ExtPorts.ai_step`, a D1 world-mediated port returning `AiStepOutcome.next_state`,
so a graded run dispatching it against a scripted provider would produce exactly the evidence
`discovery` reads. WI-D7 and WI-D8 measured that the barrier there is the declared row's vocabulary
and not the behaviour — and a dynamic producer does not read declared rows. **That run is not in this
item**, the omission stands until it exists, and it is a maintenance-register entry rather than a
goal-line blocker: clause 1 asks for *a* profile, and this is it.

### 10.4 Owed, unchanged

Door 3 (compose's `show` residue) closes by disclosure plus an upstream filing. The
registration-effects amendment stays DRAFT on the maintenance register. The fault catalogue's
`driver_only`-naming condition now has three consumers instead of two. None of the three blocks the
closing note.
