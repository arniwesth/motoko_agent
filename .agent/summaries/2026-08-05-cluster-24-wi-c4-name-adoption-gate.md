# 2026-08-05 Cluster 24: WI-C4 — the name gate run, and the blocker nobody was tracking

## Context

Branch: `arniwesth/mot-63-execute-wi-c4`.

Session span: `0dfb67a` → **`183fbbb`, one commit, working tree clean**. Input was
`HANDOFF-execute-c4-name-adoption-gate.md`, executed cold against HEAD. Twenty-fourth code session of
project 009, fourth of Milestone C. Pin **v0.33.0**.

**Window: ~40 min**, `12:46Z` → `13:26Z`. Short because the item's contract is to run gates and read
them, not to build. **The two long poles were both waiting**: the S13 whole-tree sweep (~8 min over
242 files) and `make dst` (~20 min). Roughly ten minutes of actual judgement, and it landed on a row
the plan never scheduled a producer for.

**This is the one item in the project where producing new machinery is a symptom.** It wrote no
production code. The only code written repairs an instrument that was reporting a false green, and
that repair changes no row's answer.

| Definition-of-done item | State |
|---|---|
| A verdict, row by row, with the evidence behind each | **met** — eleven rows, eleven answers, all from this run's `make dst` |
| Vacuous passes marked distinctly from real ones | **met** — rows 3 and 4's waiver, both traced to the empty install list |
| Every failing row given a named producer | **met** — four rows, four producers, in the note and lifted into the plan |
| No target adopts the "DST"/"simulation" name | **met** — seventh consecutive item, first with a run table behind the refusal |
| S13 whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1` | **met** — 225/17 of 242, failing set member-for-member |
| S9: every live cache cleared, `~/.ailang/cache/registry` untouched | **met** — 12 per-directory caches, registry intact, no reinstall needed |
| `make dst` status with each red attributed | **met** — exit 2, the same two reds since B4 |
| Planning defects named rather than filled | **met** — three, and the first explains five items of effort |

## Grounding

HEAD `0dfb67a`, tree clean — exactly what the handoff said. **Fourth consecutive handoff to get commit
state right.** One drift: the handoff header names branch `mot-62`; the branch is `mot-63`. Harmless,
and worth one line only because the instruction to confirm with `git status` rather than believe the
prose caught it for free.

## THE VERDICT: NO

Seven rows of eleven hold. Four do not. **No target adopted the name.**

| # | Row | Verdict |
|---|---|---|
| 1 | One seed generates an execution | PASS |
| 2 | Modeled logical environment | PASS (qualified — defect booked to row 10) |
| 3 | Tested boundary honest | **PASS — VACUOUS** in every installed-extension clause |
| 4 | Faults reach production recovery | **RED** — 5 of 9 required non-waived classes reached |
| 5 | Virtual time matters | PASS — real, with a transferability caveat |
| 6 | Production logic under test | PASS |
| 7 | Oracle complete | **RED** — 13 registered D6.4 gaps |
| 8 | Harness failures separate | PASS |
| 9 | Discovery and replay stable | PASS |
| 10 | Hermeticity enforced | **RED** on the host-env clause |
| 11 | Actual search | **RED** — the same four classes as row 4 |

Full row-by-row evidence in `NOTE-c4-name-adoption-gate-verdict.md`.

## The finding that reframes the project's last five items

**The blocker every handoff since B4 has tracked is not what stops the name.**

The question repeated since B4 was *"can any extension be installed?"* The answer is still no
(`on_budget_plan` is coverable under neither D5 criterion). **That was never the binding constraint.**

The boundary row's last clause — *"the result reports per-extension covered/excluded hook **ids**, so
a profile covering only ABI-pure no-op slots is visible as such"* — **anticipates a weak profile and
asks that it be VISIBLE, not that it be strong.** `driver_only` installs nothing, discloses that it
installs nothing, and records in one paragraph exactly which four slots are uncoverable and why. A
reader cannot mistake it for a covering profile. **The row passes on its own text.**

**What fails is the oracle row**, and nothing in the project was tracking it:

> Every enumerated `SystemRun` terminal path returns exactly one final `RunSummary`; **all logical
> ledger emissions appear in the returned trace**; and all D7 invariants pass.

Two conjuncts hold. The third is false for **thirteen** Logical variants in `d64_gap_register` — the
tool-dispatch fold, two terminal paths, and the closing half of the stream bracket. C3 discharged
D6.4's *named stream exception* and said in as many words that the general obligation was not; **this
row is that obligation.**

**And the confirming measurement, which matters more than the count: eleven of the thirteen are
reachable under `driver_only`.** Only `ScratchpadResult` and `ExtToolHandled` need an installed
extension. **So the row fails under every reading of "profile-reachable"** — which means the tempting
escape (narrow the profile's declared reach until the gaps fall outside it) cannot rescue it. That
removes the temptation rather than merely forbidding it, and it is the strongest form the finding
could have taken.

## The second finding: a sixth instrument that certified nothing, and this one turned nothing red

The handoff named `dst_event_vocabulary.ail:808` — *"the register carries the remaining
**fourteen**"* — as stale prose, S15's class, and stated: **"the assertion beside it is correct and
derives the list; only the prose is stale."**

**Backwards. The assertion was the stale thing.**

```ailang
List.length(logical_variants_not_in_trace(event_vocabulary())) == 14
  && contains_str(logical_variants_not_in_trace(event_vocabulary()), "StreamDelta")
```

WI-C3 flipped `StreamDelta.reaches_trace_today` to `true`. The gap became 13 and StreamDelta left it.
**`test_logical_gap_is_recorded` has been RED since WI-C3 — through two items whose reports state that
every `make dst` target but two passed.**

**The wiring is why nobody saw it:**

```make
ailang test src/core/dst_event_vocabulary.ail > /dev/null && echo "  ✓ ..."; \
```

Under `set -e` a failure on the left of `&&` **does not exit** — that is what `&&` is for — and the
following `;` discards the status. The target **printed no tick for that file and exited 0**. The same
form in *terminal* position is safe, because the recipe's status is the last command's. **That
asymmetry is why it survived seventeen sites and eight items: eleven were fine and the pattern read as
uniform.**

**Measured rather than inferred.** Six sites were non-terminal; all six were run directly and
**exactly one was masking a real failure**. The other five pass on their own. All six are now checked
commands.

**Repair verified falsifiable**, per this project's standing practice: restoring `== 14` takes
`make event_vocabulary` to **exit 2**; before the repair the identical mutant exited **0**.

**Three stale count instances, not the one named** — `dst_event_vocabulary:808`, `dst_invariants:600`,
`dst_invariants:628`. **The third consecutive item to carry S15's class**, and the first where the
stale number was propagated forward into a handoff and read as measurement.

## New standing rule

**S19. A gate's success markers are an INVENTORY, and a missing tick is a failure report.**

Every mutation rule in this project (S1, S7, S16) asks **what turns red**. Nothing asked **what
stopped printing**. This defect turned nothing red; it printed one fewer line. Read a gate's ticks as
a checklist against the files it names, because a check that vanishes is indistinguishable from a
check that passes in every signal the project was watching.

The corollary belongs beside S13: `cmd > /dev/null && echo "✓"` discards the status in non-terminal
position under `set -e` and is safe in terminal position.

## A disagreement checked rather than resolved toward the greener

The handoff's stop-and-report rule asked for gate disagreements to be reported. One surfaced.

`run_report_dst` prints **two** windows. The first shows `fault classes reached: 9 of 11` with
`provider_partial_stream_then_error: reached ×1`; the second shows `5 of 11` with the same class
`unreachable-structurally`. **Not two instruments disagreeing** — the first is the renderer's
complete-window fixture and the second is labelled in the output itself as *"TODAY's DOCUMENTED
coverage register — declared, not measured."* The measured window agrees with `corpus_pr` exactly.

Recorded because a naive read of the log gets it wrong, and because checking cost two minutes.

Also kept straight: the register reports `fault classes reached: 5 of 11` beside `recovery branches
reached: 9 of 11`. Branches are reached by constructed scenarios, classes by search. **D11 keeps them
separate precisely so a hand-written scenario's branch cannot be read as a seed's class**, and here
the separation is doing visible work.

## Where the gate is green and the ADR row is red

`make corpus_pr` passes while row 4 fails, and **this is not a defect in the gate.** The corpus holds
its bank to `expected_bank_coverage()` = required-non-waived **minus** the registered-unreachable set,
and reports the register separately and in both directions (`✓ expected + unreachable == every
required non-waived class (9)`). The narrowing is recorded, not hidden, and the module states outright
that *"a class nobody waived that nobody reached is a coverage gap, not a permission."*

**The gate passes its own contract; the ADR row is stricter.** Anyone reading `make corpus_pr` as the
answer to row 4 reads a green. Worth carrying: **a gate can be honest, well-built, and still not be
the row.**

## Vacuous versus real, because a reviewer needs the difference

Two rows pass **only because the install list is empty**, and per D10 a vacuous pass does not transfer
— a second profile earns them again from scratch:

- **Row 3's** clauses over installed extensions all range over the empty set. The gate says so itself:
  `✓ an empty install list cannot violate: vacuous for driver_only`.
- **Row 4's** `extension_effect_fault` waiver is purchased by installing nothing.

One clause is satisfied **only by a synthetic fixture**: "dispatch to an exclusion fails closed."
`make hook_guard` is 4 rows green and asserts the excluded hook's *body did not run* — but no profile
in this tree can reach it. **The mechanism is demonstrated; it is not exercised.**

And row 5 passes **for real** with a residual unrouted site, which is the distinction worth keeping:
`stub_step.ail:202` is the live adapter, and its unreachability is *evidenced* by a two-sided Clock
poison pair (deterministic completes with `Clock` withheld; live dies), not claimed. Compose's eight
unrouted clock reads are outside reach **only because nothing is installed** — that half buys nothing
for the next profile.

## The work list behind the NO

**Row 7** — close `d64_gap_register`: two terminal paths (unblocked, the same one-line append
`DoneEvent` took), the seven-variant tool-dispatch fold (where the bulk lives), `ThinkingStreamEnd`,
and three gated on an installable extension or a suspend trigger.

**Rows 4 and 11** — two producers close all four classes: an **error case on `ScriptedStep`** (closes
three) and a generator that emits malformed `tool_args` (closes one). **Neither externally blocked.**

**Row 10** — a **filesystem class in the world**, so `resolve_context_limit`'s `Env` and `FS` halves
route together. Routing the env half alone is refused on record and correctly so: it would hand back a
world-supplied path to an ambient file.

## Planning defects, named and left

1. **The oracle row has no scheduled producer.** The plan's WI-C4 text asserts *"every row's evidence
   is produced earlier"* and lists A14, A15, A4/A5, A12, A9, C3 — **no item was ever scheduled to
   close D6.4's general obligation.** This is why every handoff from B4 to C5 tracked the install: the
   row that actually blocks the name had no owner, so nothing reported on it.
2. **The host-env poison pair has no owner.** A12 was to produce the hermeticity probes and its
   specified order contains no filesystem class. `world_state`'s Makefile note already called it a
   plan finding; it was never lifted into the plan.
3. **The plan never said what to do with a NO.** "Expect NO" had to arrive by handoff. A gate that
   reports NO with a work list is the successful outcome.

All three are now written into the plan's WI-C4 entry alongside the verdict table.

## Sites where two answers type-checked and one was silently wrong: 51

**Authored none — this item wrote no production code.** **Found one pre-existing:** the stale literal
`== 14`, where both `13` and `14` type-check and the wrong one was red in a place nothing reported.
Authored by WI-C3, invisible until now.

**Counted as 51 rather than held at 50, deliberately.** Prior items counted a site at the run that
found it; holding the number would make the project's own count subject to the same silence the count
exists to measure.

**Determinism has caught none of the fifty-one. Nor did mutation catch this one** — it was found by
reading a gate's output for a tick that was *absent*, which is the observation S19 exists to
generalise.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 225 pass / 17 fail of 242.** Failing set
  matches the expected seventeen **member for member**: 7 `TC_ARITY_001` smoke scripts, the
  sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture. Stable
  across B4, C1, C3, C5, C4. **`bfs` did not abort** — S13's command is correct as corrected by C5,
  and this is the first item to run it since.
- **`make dst` — exit 2, the SAME TWO red targets as B4/C1/C3/C5:** `test_coverage` and
  `test_coverage_selftest`, attributed by B2a to module resolution in `ailang test`. **805 ✓ rows,
  NOT compared to C5's 757** — this run prints a tick the previous methodology never emitted, so a
  delta would be an invented comparison. The comparable claim is the red target set, which is
  identical.
- **`anchors`, `predicate_anchors`, `attribution_table`, `event_vocabulary`, `invariants`,
  `driver_only` — all exit 0** after the edits.
- **S18 checked and no cascade owed:** the comment edit added ~14 lines to `dst_event_vocabulary.ail`,
  and no code, script or fixture anchors a line number into that file. The two doc references sit
  above the edit.

## Traps avoided, worth carrying

- **S9's corrected recipe worked first time.** 12 per-directory caches cleared,
  `~/.ailang/cache/registry` left alone, **no registry package uninstalled and no `ailang install`
  needed** — so none of C5's fifteen-minute duplicate-dependency-key trap. The correction C5 paid for
  was banked here at zero cost.
- **The two one-line wrong answers were both available and neither was taken.** Reclassifying the
  thirteen as DisplayOnly (guarded in two places, but the reason not to is that it makes D6.4 vacuous
  for exactly the variants it covers) and narrowing `driver_only`'s declared reach (a conformance
  decision and a profile version bump).
- **The third wrong answer — answering a row by building something — did not arise**, and the one
  repair made is checked against it: it produces no evidence for any row, and row 7 is red with it in
  place exactly as it was without it.

## Deliberately not done

Closing the D6.4 register; making the four fault classes reachable; the env/FS routing; the
`on_budget_plan` ABI change and everything gated on it (compose's install, its eight clock reads,
`proc_exec`/`env_get` widening); wiring the seeded runners through `execution_of`; the extension
bridge's emission channel; the `motoko-ext-abi` major and lockstep re-release; the `ailang iface`
MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.

**And the name.** Seven consecutive items have declined it. This is the first with a run table behind
the refusal.
