# Coordinator check: does the Antithesis mutation-testing skill compare mutant and original on the same seed?

Checked first-hand on 2026-10-06, because two researchers left it open and the answer decides what
remains distinct in the claim under review.

Source: `antithesishq/antithesis-skills`, commit `1fd8470d36a9629a75bda4619a5589d679a40d7c`
(the repository's HEAD on that date, and the commit Motoko's project 035 pins). All eight markdown
files of `antithesis-mutation-testing/` were downloaded and searched: `SKILL.md` (302 lines) and
`references/` `catalog-reconstruction.md`, `evidence-and-report.md`, `mutant-design.md`,
`mutation-harness.md`, `resume.md`, `static-validation.md`, `sweep-and-verdicts.md` (1,676 lines in
all). Reading depth: keyword search over the full text of all eight, with the matching lines read.
The files were not read cover to cover. Copies are in
`/workspaces/motoko_agent/tmp/research/exa_raw/antithesis_skill_check/`.

## Findings

1. **The word "seed" does not occur in any of the eight files.** A case-insensitive search for
   `seed` returns nothing.
2. **The baseline is a gate and a control, not a per-seed comparand.** `SKILL.md` line 117:
   "**Baseline:** A run of the unpatched SUT built from the same source as every mutant. The
   control." Line 53: "A green baseline at the current code state is required before any mutant
   is". The baseline is also used to drop properties that were never exercised (line 250:
   "`example_count` 0 in the baseline means the assertion never evaluated, and a mutant nothing
   reaches cannot be killed").
3. **Runs are randomized explorations, not replays.** `sweep-and-verdicts.md` line 187: "No reach
   in one 15-minute randomized run is a sample, not proof: re-run the baseline longer first."
4. **No trace diff.** Searches for `diff`, `diffing`, `differential` and `trace diff` find only
   source diffs (the mutant patch) and a directory diff used when resuming. Nothing compares a
   mutant run's trace or history with the baseline's.
5. **Reach and divergence are observed through a marker the mutant carries**, and the survivor
   verdicts are, quoting `sweep-and-verdicts.md` lines 187 to 197:
   - "Marker red, and nothing reaches the **mutated site**" gives **bad workload**.
   - "Marker red, but the mutated site **is** reached — the workload drives execution there and
     only the divergence condition failed to occur" gives "rarity, not a gap".
   - "Marker green, divergence masked or converged before observation" gives **bad mutant**: "The
     bug ran but was erased before anything could see it."
   - "Marker green, divergence reaches the assertion but the predicate tolerates it" gives **bad
     oracle**: "The catalog has a hole and the mutant found it."
   - "No observation point could ever distinguish a violation" gives **bad property**.
   - "`setup_complete` never reached, or a container crashes deterministically on startup" gives
     "too blatant".

## What this settles

- The Antithesis skill has the reach measurement and the "ran, nothing noticed" split into masked
  divergence versus a tolerant predicate. It gets them from an instrumented marker and from
  analysis of the failing or surviving run, not from running the original and the mutant on one
  seed and comparing the two runs.
- So a same-seed, whole-run comparison against the unmutated run is not part of the Antithesis
  workflow as published at this commit. Hardware functional qualification does have that
  comparison (see `hardware_formal_mutation_coverage.md`), so the comparison itself is not new;
  what is not found is its use on a DST harness for software.
- Not checked: the shell scripts under `assets/mutation-testing/`, and whether the hosted platform
  offers a seed-pinned replay that the skill does not mention.

## Second pass: all eight files read cover to cover

Done later on 2026-10-06, at the operator's request. Reading depth is now full text for
`SKILL.md` and all seven reference files. The findings above stand. The full read adds the
following, each of which bears on what remains distinct in the thesis.

**Confirmed: no paired execution, and why the design does not need one.**

- A run is a search over many histories, not a replay. `sweep-and-verdicts.md` lines 211 to 213:
  "the mutant ran in forty histories where nothing failed, and the property failed in a
  forty-first where the mutant's branch was never taken."
- Divergence is something the mutant's author instruments. `mutant-design.md` lines 61 to 63:
  "Green means the divergence happened, red means it never did — the single most useful fact when
  a mutant survives." Lines 80 to 86 say to place the marker "where the mutation actually
  diverges", and that where this is not cheap, "the marker proves reach but not divergence".
- Propagation and detection are argued, not measured. `static-validation.md` has the author trace
  four links by reading code before any run: "Reach", "Diverge", "Propagate", "Fire". It says of
  that trace: "A trace is a prediction, not a result. It is read off code by an agent that has
  not run it."
- The baseline is used three ways: as a gate (every safety property green), as the source of the
  property list and of timings, and as a re-run at a longer duration before crediting a kill that
  only appeared at that duration.

**Things the thesis's source system also does that are therefore not distinct.**

- **A prediction before the run, with a named target.** `static-validation.md`, "Predict the
  verdict": the chain, "which property fires, and what collateral damage to expect".
  `evidence-and-report.md` lines 192 to 193 record "Predicted verdict" and "Actual verdict ...
  whether it matched the prediction".
- **A strict kill.** `SKILL.md` line 115: falsified means "The targeted property failed on that
  mutant's run, in a history carrying the mutant's marker, for a reason the log ties to the
  divergence — never merely marker-green and target-red as two run-wide counts". Other properties
  firing is "collateral damage", credited only under a stated test. A mutant that reddens much of
  the catalog is "too broad" and credits nothing. A deterministic startup crash is "too blatant".
- **The circular-kill caveat.** `SKILL.md` line 265: "Re-keying an assertion to the mutant that
  will then validate it proves nothing — the re-swept kill is circular", recorded as "falsified
  after refinement".
- **Routing each survivor to a different fix**: workload, oracle, mutant or property.
- **A build per mutant, by choice.** `mutation-harness.md` lines 160 to 162: "there is no runtime
  gate, no selector environment variable, and no dead mutant code in the baseline image".

**Things the skill states that mark where it stops.**

- **One hand-designed mutant per property, and only for properties that exist.** `SKILL.md` line
  263: "One mutant per property, modeling a realistic mistake." `catalog-reconstruction.md` lines
  22 to 25: a sweep "answers *does each assertion catch a bug that breaks its own condition?* It
  cannot answer *is anything important unasserted?*, because there is nothing to mutate for a
  property nobody wrote."
- **Self-masking is treated as a bad mutant.** `mutant-design.md` lines 113 to 117 and 135: prefer
  a mistake in the code that maintains the invariant, because "mutating the check itself often
  disables the reporting path along with the behavior"; an anti-pattern is "A mutant that also
  removes the logging or assertion that would have reported it — it hides its own effect and
  survives for the wrong reason". The thesis's source system found a class of realistic defect
  that does exactly this without touching any check (a dropped world successor carries away the
  interaction log the invariants read), and read it as a blind spot of a single-channel oracle
  rather than as a mutant to redesign.
- **The result is a count of properties falsified**, not a score and not a kill matrix beyond
  target plus credited collateral. `evidence-and-report.md` line 245: "4 of 12 in-scope properties
  were falsified."
- **Cost per mutant is a search, not a replay.** `SKILL.md` lines 144 to 151: about 5N runs for N
  properties, "roughly 45 minutes for a 15-minute run", plus about N image builds.

Still not checked: the shell scripts under `assets/mutation-testing/`, and the hosted platform.
