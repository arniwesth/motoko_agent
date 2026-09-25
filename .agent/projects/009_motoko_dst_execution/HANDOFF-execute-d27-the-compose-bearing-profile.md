# Handoff: WI-D27 — the compose-bearing profile: the demonstration

Audience: a fresh session grounded against HEAD (`aa44e93`). **Item 1 of the two remaining, and the
goal line's clause 1 made real:** a graded profile that installs compose records a real session,
replays it deterministically, and carries non-vacuous criterion-2 evidence — extension effects
world-mediated, origin-tagged, in the recorded program, reproduced by its replay. This is the debt
every report since D19 has named, and every prerequisite is now in the tree: the typed seam (D23),
the identity (D24), the audited slots (D25), the routed sites and the deterministic loop (D26).

**Read first:** the goal-line section (clause 1's exact wording is this item's acceptance test);
`src/core/dst_driver_plus_no_ops.ail` end to end (the template — D14 §the second profile);
`NOTE-d26-…` §5.1 and §13 (the scenario that becomes the session, and the named obstacle).

## What the item builds

A third graded profile — suggest `driver_plus_compose`, version `1` — in the second profile's exact
shape (measured: `no_ops_id`/`no_ops_version`, `installed_extension_ids`, `criterion_2_slot_ids`,
`measured_at` commit pin, `disclosures_of`, the `ProfileDefinition`, routed claim, coverage
substance, `validate_*`, manifest, attribution ref), plus its dst script, plus **the demonstration
run**: a full session through the **real driver** — not `dispatch_response_intercept` directly,
which is what D26's scenario drives — with a **scripted provider** emitting the compose fence, the
intercept chain running compose's real bodies, the routed `ailang check` served from
`WorldState.ext_effects`, and the whole thing recorded, validated, and strictly replayed. D26's
`compose_check_scenario` is the ~30-line core; the profile lifts it one level, to the session loop.

## The four constraints, each measured, and the shape they force

**1. Registration runs ambient, and the profile cannot pretend otherwise.** Compose's
`register_with_config` reads `getEnvOr("MOTOKO_PROFILE_DIR", ".")` (`register.ail:9`) and
`fileExists`/`readFile` (`config.ail:39-40`), capabilities are per-process, so **the profile's runs
grant `Env` and `FS` and the withheld-capability poison discipline does not extend across compose's
registration.** The determinism claim rests on the record → strict-replay identity instead, and the
profile's boundary note says so explicitly (D14's boundary-note pattern). Registration's three
sources are **disclosed** through the existing D5-field-9 mechanism (`disclosures_of` — built,
non-vacuous since D14). **Do NOT land the registration-effects amendment in this item** — it is
DRAFT, on the maintenance register, and the disclosure mechanism suffices for the profile record.

**2. Compose is installed and DISCLOSED, not criterion-covered — and the claim text must say
exactly that.** Verified at `make profile_definition`: **the three barriers stand** (`on_pre_step`,
`on_response_intercept`, `on_solver_candidate`, each unconditionally dispatched with a non-empty
declared row), and compose is HOOK-UNRESOLVED on door 3. So the profile's `coverage_statement` and
`CoverageSubstance` claim the **dynamic** evidence — the recorded run's discovery findings — and
nothing classifier-shaped. Clause 1 was worded for precisely this split ("a dynamic fact, not a
classifier verdict"). S25: every claim in the profile record states what it is conditional on; the
final rerun (item 2) will read these fields into the vacuity register, so an overclaim here
poisons the closing note.

**3. The vacuity must be UN-leaned by an assertion that can go red.** The empty install list is
what four acceptance rows lean on (S21). The profile's dst must carry the row that makes the
non-vacuity executable: **the graded run's recorded program contains ≥ 1 `ExtensionEffect`
interaction whose origin is `compose`, world-mediated, and the strict replay reproduces it** — red
if compose is dropped from the install list, red if the intercept path breaks, red if the
recording regresses. This is D13's lesson inverted: a vacuity that arrives with a number is the
hardest to see, so the non-vacuity must arrive as an assertion, not a number in prose.
`DiscoveryWitness.extension_effects` is hand-maintained by design (D24) — the scenario sets it, and
the ext_effects queue carries **slack** (more entries than consumptions, S7-distinct values,
distinct from every existing queue constant: -1/0/1/41…61/71/73 are taken), because an empty queue
does not fail, it **delegates** — a live `bash -lc` inside the graded gate is the failure mode the
slack prevents (D24 §4, D26 §5.1).

**4. The third profile joins every cascade, and the consumer list is the OWED S22 derivation.**
S18's extension recorded it: *"a third profile extends the list again with nothing naming it in
advance."* Derive, from producers, every place the second profile appears and add the third:
the D4 re-issue check (attribution ref + `content_hash` + the sweep's "this profile was not
re-issued" guard), `anchors.sh`'s width-law grep (verify the grep's file set FINDS the new files —
a glob that misses them under-covers silently, D16's pin lesson), `check_abi_version`'s site scan
(it found "6 sites across 4 files"; the new profile's transcriptions must join the derivation —
prove it by count, and remember the gate red-flags zero sites but not a missed file),
`profile_coverage`/`profile_definition` fixtures, the `make` aggregate, and the Makefile target.
Report the derived list and its producer for each entry.

## The session mechanics, measured

The intercept path is the deterministic loop (D26 §13.3: `handle_compose_tool` calls
`callStreamResult` — ambient AI — before anything routed; **do not** demonstrate through the tool
path). The scripted provider supplies the fenced response, so the session needs: scripted model
steps (the fence content — reuse D26's fixture snippet with its real `ailang check` diagnostic),
the `ext_effects` queue for the routed check, compose's registration inputs (`MOTOKO_PROFILE_DIR`,
config file present or honestly absent — pick and record), and whatever the driver's loop consumes
(approvals/tools per the scenario families). The run goes through the **traced** entry point so the
recorded program is D8-persistable; validate → `world_state_of` → strict replay is the round trip
the demonstration asserts. Compose's `on_budget_plan` is a constant and `on_pre_step` /
`on_solver_candidate` bindings are passthrough-shaped (`compose.ail:1118-1126`) — they will run in
the loop; D25's audits say the successors thread.

## Definition of done

1. The profile loads clean and its dst is green: install, registration disclosed, the
   demonstration session recorded → validated (0 rejections) → strictly replayed (0 mismatches,
   nothing unconsumed), the non-vacuity row asserting origin-tagged compose effects in the program.
2. The un-install mutant: remove compose from the install list — the non-vacuity row goes RED and
   names what vanished; restore per S17. A second mutant worth its cost: serve the check from the
   wrong queue (the D24 M3 shape) — the served-content row must catch it at session level.
3. All cascade joins verified by their own gates: `anchors`, `predicate_anchors`,
   `attribution_table` (three consumers now), `check_abi_version` (site count grew, derivation
   stated), `profile_definition`, `profile_coverage`, the sweep aggregate with the new target.
4. Existing verdicts unmoved: yields (5/15, 4/15, 4/15), inventory (compose 8/36),
   `declared_vs_performed` 46/0, both existing profiles' versions untouched (this item adds a
   profile; it does not re-issue the others unless an anchor moves — package-side plus
   scripts-side edits should move none).
5. The three standing reds unchanged, nothing new; `make sync_packages` per D22 if any type is
   touched (none should be).
6. Counters: expect no movement — this item assembles evidence; count nothing authored-and-closed.

## Out of scope, per the goal-line rule

- **The final acceptance rerun** (item 2) — this item produces the profile and its evidence; the
  rerun reads them. Do not rewrite acceptance rows here.
- Landing the registration-effects amendment; door 3; any barrier-row widening; the
  `proc_exec` rename.
- Making `handle_compose_tool` deterministic (the AI boundary — register, not queue).
- The other twelve extensions' profiles.

## Stop and report rather than deciding inline

- If the session loop cannot reach the intercept deterministically with the world's existing
  queues — a new queue or a core reconstitution change is a finding, not a fix-in-passing (D24
  finished that surface).
- If any cascade consumer cannot be joined without editing an anchored region of `session.ail`,
  `ext/runtime.ail` or `tool_phase.ail` — price it first (the width law says which files re-issue).
- If the demonstration turns out to require granting a capability whose only consumer is an
  UNdisclosed ambient site — that is a new ambient source nobody counted, and the inventory's
  15/15 resolution claim is what would be wrong.
- If compose's registration behaves differently under the profile's env/config inputs than the
  inventory's accounting assumes (a config-conditional effect path) — measure and report; the
  disclosure must match what runs.

## Report back

`NOTE-d27-…` in the established form: the profile record's fields and every claim's condition; the
demonstration's quantities and its round trip; both mutants; the cascade-join table with each
consumer's producer; what granting `Env`/`FS` across registration actually exposed; and what the
final rerun (item 2) inherits — in particular, the exact machine-readable places its vacuity
register and classification table should read, because that note is the project's closing document
and this item decides how much of it is computed.
