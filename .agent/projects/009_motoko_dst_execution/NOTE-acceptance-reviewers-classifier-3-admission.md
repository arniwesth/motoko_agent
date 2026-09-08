# Governance act — classifier 3 admitted, classifier 1 ruled on, and the criterion amended

**Both ADR-001 acceptance reviewers, jointly.** Grounded against HEAD `2e411f3`. **One file modified:
`ADR-001-deterministic-test-world-architecture.md`. Zero source files. Barrier count derived at 3
before the edit and unmovable by it.**

---

## 1. Classifier 3 — ADMITTED, with one condition. The count is FOUR.

Admitted as the fourth deferred gate mechanism, unanimously. **Deferred count 3 → 4. Total mechanisms
in the table 4 → 5.**

**The condition, which is ours and not the review's:** the admission holds only while the barrier
count is *derived* rather than asserted. `basis` must land on `HookClassificationEntry` with or
before any change that lowers the barrier count, whichever comes first. Reasoning is under the table.

## 2. The architecture test — applied by both, on two arms, recorded in the ADR

*"If classifier 3 turned out unbuildable, would D1–D11 still be the right architecture?"*

**Arm 1 — what would have to change: nothing, and the counterfactual is the observed state.** HEAD
*is* the classifier-3-absent world — barriers 3, `driver_only` installs nothing, zero classification
entries. The architecture was accepted in that state. **Yes.**

**Arm 2 — is the degradation conservative, and what carries it.** Cost is coverage, not correctness:
the opposite direction from coverage-floor validation, the one deferred mechanism that fails open.
**Yes — but the fail-closed default is prose.** `classification_agrees` checks a `WorldMediated`
entry against the excluded-id list and nothing else; `HookClassificationEntry` has no `basis` field.
What makes the absence conservative is the derived barrier count, not the rule. Hence the condition.

**The D5-level escalation does not fire**, and this was re-verified from the compiler's own interface
data rather than from the review's probes: `ExtensionHooks.on_pre_step` carries the concrete label
set `{AI, IO, Trace}` with **no row variable**, `on_response_intercept` `{Clock, FS, IO, Process}`,
`on_solver_candidate` `{Process}`. Closed rows a named binding cannot narrow. The extension model is
uncovered, not uncoverable — the route is an ABI change already inside the deferred major.

## 3. The ruling on classifier 1 — reading 3, and the measurement does not reproduce

**The reading: neither "Built" nor "Deferred". "Deferred" would be false — nothing is left for the
plan to build, and it would misdirect the repair, which is an upstream `MOD010` fix plus a `make dst`
wiring change. Plain "Built" reads as a warrant the mechanism no longer earns.**

**But the measurement WI-D10 and the amendment review both recorded does not reproduce.** Re-run four
consecutive times from the repository root, same v0.33.0 pin:

```
make effect_inventory           EXIT 0   INTERFACE FAILURES (45), not 46 -- std/env alone resolves
                                         21 imported std/* modules, ZERO unresolved
make effect_inventory_selftest  EXIT 0   self-test: agree=1 disagree=0
```

**Classifier 1's criterion as written is MET at HEAD, in both clauses — and that is worse than the
red that was reported.** `derive.py`'s guard is `if agree + disagree == 0`: a **zero-check, not a
coverage check**. One comparable module out of forty-six turns "a pass-shaped absence, not a pass"
into a literal pass, and both targets go green while 45 of 46 classifications still come from the
unvalidated textual fallback. **The failure mode WI-D10 caught got harder to see, not easier.**

**So the defect is in the criterion, and amending a criterion in this table is ours.** The criterion
now requires the self-test to compare **≥90% of the stdlib modules the profile's roots import**.
Against the amended criterion classifier 1 **fails**, and it blocks the name.

**Two corrections to the record, both carried forward across three documents without a re-run:** it
is **45 of 46** interface failures, not 46 of 46; and the failure exit is **1**, not 2 — `derive.py`
returns 1 there and reserves 2 for harness error. Run from a directory under `/tmp` the same target
reports `agree=46 disagree=0`, because AILANG auto-relaxes `MOD010` inside a temp directory —
`derive.py`'s own docstring warns about it. **The repository root is the only legitimate cwd for
either target.**

**Why `std/env` alone resolves is an AILANG-side question**, stable across four runs and independent
of cwd-relative caches. It is an addendum owed to the existing `MOD010` filing, not a finding against
this tree.

## 4. WI-D10's cell edit — REVISED, not ratified

Its judgement was right and its flagging was right: a status table reading "Built and independently
verified" against a mechanism certifying nothing is the artifact a future reader trusts. **Its factual
claim — "its acceptance criterion is NOT met at HEAD" — is false as measured.** The State cell now
reads *"Built, and passing a criterion that no longer certifies what it was written to certify"*, and
the qualification beneath the table is replaced.

## 5. What the reviewers re-derived rather than accepted

- **Yield 4 of 15, reproduced from source.** Fifteen extensions resolved through `ailang.toml`, not
  by directory-name convention; closures 2–17 modules; **zero unresolved imports**; exactly
  `decision_framework`, `compaction_structural`, `empty_stop_guard`, `progress_contract_guard`.
- **The producer-conditioning is new and is ours.** `std/json` exports 38 symbols, **33 with no
  effect row at all**, one of them `jo` — imported by three of the four clean extensions. On the
  textual route those are UNRESOLVED and all three are refused: **1 of 15, not 4.** The compiler's
  cached interface answers `jo` positively (`purity: true`, empty effect row). **The cheapest
  producer would have destroyed the result the amendment names as the cheapest path to non-zero
  coverage.** The criterion therefore requires a compiler-derived producer by name.
- **Barrier count 3**, derived from `make profile_definition`: `on_pre_step`,
  `on_response_intercept`, `on_solver_candidate`; `on_budget_plan` coverable, `on_tool_handle` gated.

## 6. Count agreement, checked rather than assumed

| Site | Reads |
|---|---|
| `:20` Status block item 2 | **four** deferred, plus the fifth built-and-failing |
| `:49` "what remains" | **four** deferred + classifier 1's repair |
| `:2391` section header | **five** detection/validation mechanisms |
| `:2463` "None of the … blocks acceptance" | **four**, plus classifier 1 blocking the name |
| `:38` the 2026-08-02 test | **three** — left as the historical record, and re-tensed to say so |

**Two live count sites beyond the two the handoff named were found and moved** (`:49`, `:2391`), plus
the "one is built; three are deferred" sentence. Leaving either would have reproduced this project's
most-recorded failure exactly.

The acceptance-review block (`:10501` onward) states "three" in several places and is **untouched**:
it is dated historical record, per plan rule S15.

## 7. Not done, deliberately

- **Citation offsets.** Not applied, on WI-D10's ground. A named anchor `#adr-gate-mechanisms` was
  added for the table and used by the new cross-reference; the ~130 new lines introduce **zero**
  numeric ADR self-citations.
- **`ADR:1493`'s "not made by this amendment"** is still true and was left alone.
- Repairing classifier 1, wiring `effect_inventory` into `make dst`, building classifier 3, WI-C5's
  cost estimate, the fourteen `register_with_config` rows — all still owed.

## 8. Owed, newly

1. **Amend `derive.py`'s guard to a coverage check**, matching the amended criterion. The zero-check
   is the reason a 45/46 degradation reads green.
2. **Addendum to the `MOD010` filing:** one stdlib module resolves and forty-five do not, which is
   what converts the fail-closed guard into a pass.
3. **`make effect_inventory{,_selftest}` must run from the repository root** — record it where the
   targets live, not only in `derive.py`'s docstring.
