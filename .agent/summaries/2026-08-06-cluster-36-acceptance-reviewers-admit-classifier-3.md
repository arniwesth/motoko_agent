# 2026-08-06 Cluster 36: both ADR-001 acceptance reviewers — admit classifier 3, rule on classifier 1

## Context

Branch: `arniwesth/mot-73-wi-d10-land-amendments-b-and-a`.

Session span: `2e411f3` → **uncommitted**. **No source file changed.** One document modified
(`ADR-001-deterministic-test-world-architecture.md`), two added. Input was
`HANDOFF-acceptance-reviewers-admit-classifier-3.md` (`2e411f3`), grounded against HEAD `2e411f3`.
Pin **v0.33.0**.

**A governance act, not an execution item.** The handoff scoped it at "four cells and two sentences in
one table, and one ruling that is harder than it looks." The count moved as directed. **The ruling
inverted the fact it was asked to rule on**, because the measurement WI-D10 and the amendment review
both recorded does not reproduce.

Input documents: `REVIEW-adr-001-criterion-2-amendment.md`, `NOTE-d10-land-the-amendment.md`, the
amended `ADR:1470-1580`. Output: the amended ADR and
`NOTE-acceptance-reviewers-classifier-3-admission.md`.

| Definition-of-done item | State |
|---|---|
| Count moved in both places, or not at all | **met** — and in **four** live places, not two |
| Classifier 3's row carries a criterion, not a description, stating the yield | **met** — and the yield is producer-conditioned, which is new |
| D10's classifier-1 cell edit ratified or revised, explicitly | **met** — **REVISED**; its judgement stands, its fact does not |
| Architecture test applied by both, recorded, not cited | **met** — two arms, one new condition attached |
| Nothing else in the ADR touched; no source files | **met** — one `.md` modified, barrier count 3 before and after |

---

## The item's central inversion: the mechanism went GREEN, and that is worse

WI-D10 and the review before it both recorded classifier 1 as failing: all 46 `ailang iface` calls
failing `MOD010`, `agree=0 disagree=0`, "a pass-shaped absence, not a pass." The handoff asked
whether a mechanism whose acceptance criterion is unmet is still "Built."

**Re-measured four consecutive times from the repository root, same pin:**

```
make effect_inventory           EXIT 0   INTERFACE FAILURES (45), not 46 -- std/env alone resolves
                                         21 imported std/* modules, ZERO unresolved
                                         13 effect-bearing, 8 proven effect-free
make effect_inventory_selftest  EXIT 0   self-test: agree=1 disagree=0
```

**The premise of the question is false. Classifier 1's criterion as written is MET at HEAD, in both
clauses.** The guard in `tools/effect-inventory/derive.py` is `if agree + disagree == 0` — a
**zero-check, not a coverage check**. Exactly one comparable stdlib module out of forty-six converts a
pass-shaped absence into a literal pass, and both targets go green while 45 of 46 classifications
still come from the unvalidated textual fallback.

**So the defect moved from the tool to the criterion, and amending a criterion in this table is the
acceptance reviewers'.** The criterion now requires the self-test to compare **≥90% of the stdlib
modules the profile's roots import**. Against the amended criterion classifier 1 **fails and blocks
the name**. The deferred count stays four; the name turns on five.

**The failure mode WI-D10 caught got harder to see, not easier** — a red gate nobody was listening to
became a green gate that certifies 2.2% of its surface.

### Two numbers carried across three documents without a re-run

- **45 of 46** interface failures, not 46 of 46.
- The failure exit is **1**, not 2 — `derive.py` returns 1 on that path and reserves 2 for harness
  error. The quoted FAIL text is a string literal in the source, which is a plausible way to have the
  words without the run.

Run from a directory under `/tmp` the same target reports `agree=46 disagree=0`, because AILANG
auto-relaxes `MOD010` inside a temp directory — `derive.py`'s own docstring warns about this.
**The repository root is the only legitimate cwd for either target**, and nothing records that where
the targets live.

---

## Classifier 3 — ADMITTED, count 3 → 4, with a condition that is the reviewers' own

Table total 4 → 5 mechanisms; deferred 3 → 4.

**The architecture test, applied on two arms rather than inherited.**

- **Arm 1 — what in D1–D11 would have to change: nothing, and the counterfactual is already the
  observed state.** HEAD *is* the classifier-3-absent world — barriers 3, `driver_only` installs
  nothing, zero classification entries. The architecture was accepted in that state. **Yes.**
- **Arm 2 — is the degradation conservative, and what carries it.** The cost is coverage, not
  correctness — the opposite direction from coverage-floor validation, the one deferred mechanism
  that fails open. **Yes, but the fail-closed default is prose:** `classification_agrees` checks a
  `WorldMediated` entry against the excluded-id list and nothing else, and `HookClassificationEntry`
  has no `basis` field. What makes the absence conservative is the **derived barrier count**, not the
  rule.

**Condition attached:** the admission holds only while the barrier count is derived rather than
asserted. **`basis` must land with or before any change that lowers it.** If barriers ever cleared
while `basis` were absent, classifier 3's absence would stop degrading conservatively and start
licensing an unevidenced claim.

**The D5-level escalation does not fire**, re-verified from the compiler's own interface data rather
than the review's probes: `ExtensionHooks.on_pre_step` carries the concrete label set
`{AI, IO, Trace}` with **no row variable**, `on_response_intercept` `{Clock, FS, IO, Process}`,
`on_solver_candidate` `{Process}`. Closed rows a named binding cannot narrow — so the blocker is the
ABI, not the classifier layer, and it already sits in the deferred `motoko-ext-abi` major.

### The yield is producer-conditioned, and that is new

4 of 15 reproduced from source — fifteen extensions resolved through `ailang.toml` rather than by
directory-name convention, closures **2–17 modules**, **zero unresolved imports**, exactly
`decision_framework`, `compaction_structural`, `empty_stop_guard`, `progress_contract_guard`.

**But the amendment's two conditions had never been read against each other.** A-1 names the textual
per-declaration parse as the fallback route; A-3 states the yield as 4 of 15. Reading both:

```
std/json          38 exports,  33 with NO effect row at all  (one of them `jo`)
imports `jo`      compaction_structural, empty_stop_guard, progress_contract_guard
textual route     those 33 are UNRESOLVED -> all three REFUSED -> yield 1 of 15
cached iface      `jo` -> purity: true, empty effect row      -> yield 4 of 15
```

**The cheapest producer would have destroyed the result the amendment names as the cheapest path to
non-zero coverage** — `compaction_structural`, whose three barrier-slot bodies are measurably
effect-free. The criterion therefore names a compiler-derived producer
(`.ailang/cache/compile/modules/*/iface.json` or `ailang iface` stdout) by hand and forbids the
textual route.

---

## Count agreement, checked rather than assumed

| Site | Reads |
|---|---|
| `:20` Status block item 2 | **four** deferred, plus the fifth built-and-failing |
| `:49` "what remains" | **four** deferred + classifier 1's repair |
| `:2391` section header | **five** detection/validation mechanisms |
| `:2463` "None of the … blocks acceptance" | **four**, plus classifier 1 blocking the name |
| `:38` the 2026-08-02 test | **three** — left as historical record, and re-tensed to say so |

**The handoff named two sites. There were four live ones**, plus the "one is built; three are
deferred" sentence and "the four mechanisms below." Leaving any would have reproduced this project's
most-recorded failure — a fact correct in one place and wrong in another — on the exact item that
warned about it.

The acceptance-review block (`:10501` onward) states "three" in several places and is **untouched**:
dated historical record, per S15.

---

## Gates

- **Barrier count 3**, derived from `make profile_definition` **before and after** the edit:
  `on_pre_step`, `on_response_intercept`, `on_solver_candidate`; `on_budget_plan` coverable,
  `on_tool_handle` gated.
- **`make effect_inventory` / `effect_inventory_selftest`** run four times from the repository root
  and once from a temp cwd, as the measurement above.
- **Deferred-mechanism count 3 → 4**, which is this act's whole purpose.
- Full `make dst` and the cache-cold sweep **deliberately not run**: the act changed zero source
  files and one `.agent/` document, and the barrier count is the only derived number it could have
  moved. It did not.

---

## Rules earned

Extending **S15** (a fact carried forward is a fact not measured):

- **A number quoted verbatim from a tool's source is not a measurement.** The "pass-shaped absence"
  text is a string literal in `derive.py`; having the words is not evidence of having run it. When a
  document quotes a tool's own failure message, re-run the tool.
- **A fail-closed guard written as a zero-check is not fail-closed.** `agree + disagree == 0` catches
  total absence and nothing else; one sample out of forty-six passes it. **Guards on coverage must
  measure coverage, not emptiness** — and the acceptance criterion that accepts such a guard is the
  actual defect.
- **A gate going green is a weaker signal than a gate going red, and needs the same scrutiny.**
  This mechanism degraded from `agree=43` to `agree=1` and reported success both times.
- **Tool behaviour that depends on cwd will be measured from the convenient cwd.** `/tmp` auto-relaxes
  `MOD010` and turns `agree=1` into `agree=46`. Record the required cwd where the target lives, not
  only in the tool's docstring.
- **Two accepted conditions can contradict each other without either being wrong.** A-1's fallback
  route and A-3's yield are each correct; read together they give 1 of 15, not 4. **Conditions are
  reviewed individually and shipped jointly — read them against each other before applying.**

---

## Calibration

- **Thirty-fifth calibration run.** No new site admitting two type-checking answers with a silent
  wrong one — **still 66 across thirty-five runs, and determinism has caught none.** This act wrote no
  AILANG.
- **The near-miss was accepting the handoff's framing.** The ruling was posed as three readings of
  "is an unmet criterion still Built"; taking any of the three would have produced a well-formed,
  plausible, entirely wrong answer, because the criterion is met. **Caught only by running the two
  targets instead of reasoning about their reported output** — the same shape as WI-D10's own
  near-miss, one level up.

## Owed, newly

1. **Amend `derive.py`'s guard to a coverage check**, matching the amended criterion. The zero-check
   is why a 45/46 degradation reads green.
2. **Addendum to the existing `ailang iface` `MOD010` filing:** one stdlib module resolves and
   forty-five do not, and that asymmetry is what converts the fail-closed guard into a pass. Why
   `std/env` alone resolves is an AILANG-side question, stable across four runs.
3. **Record the required cwd** for `make effect_inventory{,_selftest}` where the targets live.

## Owed, carried forward unchanged

4. **Repair classifier 1** against its amended criterion, and **put both targets into `make dst`** —
   the second is the precondition for the first.
5. **Build classifier 3**, with `basis` landing with or before any barrier-count change.
6. **Re-derive the ADR's internal citation layer** (105 provably wrong pre-D10). Not offset here
   either; a named anchor `#adr-gate-mechanisms` was added and used, and the ~130 new lines introduce
   **zero** numeric ADR self-citations.
7. **WI-C5's owner** to revise the Route B cost estimate.
8. **The fourteen `register_with_config` rows.**

## Operational

- The `make run` / `ailang run src/core/supervisor.ail` session started **2026-08-04 22:49** is still
  running (**1d 19h+**), on the vendored `ailang/bin/ailang` rather than the PATH binary. Not a gate.
- **`make sync_packages` was not run** and `ailang.lock` did not move — the first item in six not to
  need it, because nothing here compiled the tree.
