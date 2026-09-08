# 2026-08-07 Cluster 37: WI-D11 — does the name adoption stand?

## Context

Branch: `arniwesth/mot-73-wi-d10-land-amendments-b-and-a`.

Session span: `a25de2a` → **uncommitted**. **No source file changed. No document amended.** One file
added (`NOTE-d11-does-the-name-adoption-stand.md`). Input was
`HANDOFF-execute-d11-does-the-name-adoption-stand.md`, grounded against HEAD `a25de2a`. Pin
**v0.33.0**. Window `09:13:33Z` → `09:37:02Z`, ~24 minutes.

**A determination, not a build.** The question: `ADR:2463-2469` says the name turns on five
mechanisms, four unbuilt and one failing; `m-motoko-dst-framework.md` records the name as ADOPTED
2026-08-06. Both statements are in the tree. Which is right.

The handoff's framing was that the contradiction predates the governance act — the same sentence
stood at `5ecd858` with "three" — so the real question was whether **WI-D5's adoption was sound when
it was made**, which nobody had asked.

| Definition-of-done item | State |
|---|---|
| An answer: stands / does not / stands qualified, tied to specific rows | **met** — **STANDS, QUALIFIED** |
| Classifier 1's status under a stated cache precondition, or declared unbounded | **met** — bounded, and the bound is a finding |
| Remedy proposal if the answer is no | **n/a** — the answer is not no; public record untouched |
| Sweep cache-cold with `AILANG_RELAX_MODULES=1`, including the stdlib-adjacent cache | **met** — 226/17 of 243 |
| `make sync_packages` first, then `make dst` in full | **met** — EXIT 0, then EXIT 2 on D5's red set exactly |
| WI-D5's report not re-dated (S15) | **met** — untouched |

---

## The item's central inversion: the blocking sentence's antecedent is FALSE, and has been for four days

The handoff expected the item to adjudicate whether `ADR:2463`'s "blocks the name" is a third
condition on D10 or a constraint on one class of evidence. It is the latter, and the document says so
three times. **But the constraint turned out not to bind, for a reason nobody was looking for.**

The operative citability statement is not `:2463` at all — it is the verification gate on obligation
2, `ADR:2036-2041`:

> Classifier 1 is built and was independently run … that half of the audit is citable. **Classifier 2
> is not built, so D5's routing audit as a whole remains non-citable as name-adoption gate evidence**
> until it is.

**Classifier 2 was built on 2026-08-03 at `5ad3433` (WI-A4)** and has been in `make dst` and CI ever
since. `NOTE-cluster-2` records its definition of done as met. Re-measured at HEAD:

```
make ext_call_inventory            EXIT 0
  CLASSIFIER-2 SET (2): env_get, proc_exec   -- membership DERIVED from the criterion
  member call sites (0):                     -- zero unresolved
make ext_call_inventory_selftest   EXIT 0    self-test: 0 failure(s)
  ok  control_resolved / form_alias / form_computed / form_reexport / form_wrapper
```

Type-aware, over `src` + `packages`, fail-closed on all four unresolvable forms with a resolving
control beside them. **That is `ADR:2410`'s criterion, met.** So the routing audit's stated blocker
had been discharged for three days when WI-D5 adopted the name, and the adoption was sound.

**WI-D5 was right without checking.** Its verdict section checks D10's two conditions and never
mentions citability; neither did its handoff. That distinction is recorded because the next item in
this position may not be as lucky.

## The per-row reasoning — the item's durable output

The constraint bites on **exactly one row**, and the handoff's two candidates split:

- **Row 5 IS a dependency.** `ADR:2547` names the routing audit in its own text, and its evidence
  (`driver_only.routed_set_claim`, reproduced at `7 reachable = 6 routed + 1 declared-unrouted`) is
  that audit's output. `ADR:940-942` forecloses reading it as the separate clock-audit bullet: the
  source/ABI audit *"is the one a profile depends on"*, with capability-withholding a per-run backstop
  that *"cannot on its own discharge the all-or-nothing routing requirement."*
- **Row 3 is NOT.** Its classifier-2 clause is **vacuous** — `driver_only` installs nothing, so the
  quantifier is empty and the clause holds whether or not the classifier exists. A vacuously-true
  clause borrows no warrant from the instrument it names. **This is the fifth thing the empty install
  list buys**, where D5 counted four.

The other nine rows name no mechanism. So the whole question reduced to one instrument's citability.

## Classifier 1 — the measurement IS bounded, and the bound is the new fact

The denominator the amended criterion needs is printed by the tool: **`repo imports 21 distinct std/*
modules`**. Measured per module in four cache states:

| Cache state (`~/.local/share/ailang/std/.ailang/cache/`) | selftest | coverage of 21 | criterion |
|---|---|---|---|
| 230 files (as found) | `agree=45` | **21/21 = 100%** | passes |
| cleared | `agree=1` | **0/21 = 0%** | fails |
| after cache-cold 243-file sweep | `agree=1` | — | fails |
| **after `sync_packages` + `make dst` in full, from cold** | **`agree=1`** | **0/21 = 0%** | **fails** |

Two-sided: the 230 files were archived, cleared, and restored; coverage moves 100% → 0% → 100% on an
unchanged tree.

**The new fact that converts "unbounded" into an answer: no repository operation produces the
230-file cache.** A 243-file cache-cold `ailang check` sweep leaves it at **0**; `make dst` in full
leaves it at **52**, selftest `agree=1` in both. **The `agree=45` state was found in this environment
and cannot be re-established by anything this project runs.** A criterion met only from a cache no
gate can rebuild is not met.

**What it costs is bounded too: the derived set is cache-invariant.** 13 effect-bearing / 8
proven-effect-free, byte-identical at 0 files and at 230. What is unavailable is not classifier 1's
answers — it is the evidence that they are right.

## Three findings reported rather than resolved

**F1 — the ADR's gate table contradicts the ADR's own body on three of five rows.** `:2410` says
classifier 2 "Deferred" while `:1972` describes its running tool; `:2411` says the attribution table
"Deferred" while `:1170-1172` (a 2026-08-03 amendment) says *"The table now exists and validates"*;
`:2412` likewise against `:1333`. `ADR:2036-2038` is stale in both directions at once — "Classifier 2
is not built", and classifier 1's half "is citable" on `agree=43`, which `:2444` contradicts.
**The governance act's §6 checked five *count* sites and found two the handoff missed; the
disagreement is in the State column, which it did not check.** Acceptance reviewers' pen.

**F2 — `dst_driver_only.ail:597` does cite classifier 1**, as the handoff said. All six named modules
are in the effect-free set under both cache states, so the claim is **true**; only its warrant is
weak. It is an omission rationale, not row 3's evidence — row 3 passes on *disclosure*, not on the
reason paragraph being sound.

**F3 — the producer-side completeness check is fed its own output at the only real call site.**
`dst_attribution_table.ail:446-448` states the rule: *"The discovered set is an ARGUMENT, never a
constant … hardcoding it here would make this check agree with itself by construction."*
`attribution_table_dst.ail:208` passes `head_inventory()` (`:133-139`), which is
`unconditional_core_sites() ++ [the two sites that ARE attribution_rows()]` — the union of the two
lists the check validates membership against, so it **cannot reject over it**. The negative fixture
proves the rule discriminates; no source inventory feeds the instrument. This stands behind row 5's
site set being complete.

## Gates

- **Sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243.** Run first per S13.
  **Cache-cold this time includes `/home/motoko/.local/share/ailang/std/.ailang/cache/`**, which S9's
  own sweep misses by construction. Failing set matches the expected seventeen member for member —
  stable across B4, C1, C3, C5, C4, D3, D4, D5 and now D11.
- **`make sync_packages` EXIT 0**, run first. Its only tree effect was `ailang.lock`'s `generated_at`
  timestamp, reverted.
- **`make dst` EXIT 2, red set `test_coverage` + `test_coverage_selftest` and nothing else** —
  identical to D5's. All row-3 and row-5 producers green.
- **Barrier count 3, DERIVED** by `make profile_definition`. **Deferred count left at four.**
- **Profile is now `driver_only/12`** under manifest `driver_only/3`; D5's table ran at `/10`. Both
  bumps are recorded claim-only — install list, coverage claim, waived set, classifications,
  catalogue and attribution ref unchanged — so D5's verdict transfers. **The public record names
  `/11` and is one version behind.**

## Calibration

**Two-answer sites: three, all in claims and citations, none reachable by any determinism check.**
This item wrote no code, which is exactly what the handoff predicted about the last four. Running
total **69 across thirty-five runs**.

1. **"Deferred" in the gate table's State column.** Live status vs ADR-time allocation of work
   (`ADR:2396` frames the section as *"the boundary between 'the ADR decides it' and 'the plan builds
   it'"*). Both readings are supported. **The wrong one is silent because the classifier-1 row's State
   column IS live-maintained** — edited twice in four days — which teaches every reader the column
   tracks HEAD. This is the reading the whole question turns on and no session had adjudicated it.
2. **"the routing audit" in row 5.** `ADR:1799-1804` lists the source/ABI routing audit and the
   profile-reachable clock audit as **separate bullets**; row 5's clause type-checks against either,
   and only one carries a citability constraint. The wrong reading is silent in the dangerous
   direction — it makes row 5 unconditionally citable with no marker, which is the R2 defect
   (`ADR:4875-4894`) not fully closed.
3. **`head_inventory()`** — F3. Both readings produce a `[CoreSite]`; the wrong one is **green**,
   which is the failure mode the module's own header exists to refuse.

## Rules earned

- **A stale antecedent is a live defect, and it fails in the safe-looking direction.** Three sessions
  read `ADR:2463`'s "blocks the name" as binding. None checked whether the mechanism it names as
  unbuilt was still unbuilt. **Reading a blocker is not verifying it** — and a blocker that has
  quietly been discharged makes a project *more* conservative than the evidence requires, which is why
  nothing goes red and nobody looks.
- **A gate whose input is derived from the lists it validates is green by construction, and stating
  the prohibition in the module header does not prevent it.** F3's module says exactly what not to do,
  two hundred lines above the call site that does it.
- **Bound a cache-dependent measurement by asking what the project can reproduce, not by averaging
  what sessions observed.** Three sessions got `agree=0/1/45` and treated the spread as noise. The
  resolving question was which states the repository can *reach*: two of the three, and the third is
  unreachable.

## Owed, newly

- **F1 to whoever owns the ADR's gate-mechanism table** — three State cells and the verification-gate
  box at `ADR:2036-2041`, which is stale in both directions simultaneously.
- **A cache-state precondition on any repair of classifier 1**, or the repaired gate measures the
  cache again. Added to the existing repair obligation at `ADR:2459-2461`.
- **F3**: supply `validate_completeness` a real discovered set from a source inventory.
- **The public record's `/11` → `/12`** — record maintenance, not a claim change.

## Owed, carried forward unchanged

Building classifier 3 (WI-D12, now handed off); repairing classifier 1; amending `derive.py`'s
zero-check to a coverage check; wiring `effect_inventory` into `make dst`; the `MOD010` addendum; the
`basis` field on `HookClassificationEntry`; Route B; WI-C5; the fourteen `register_with_config` rows;
the `motoko-ext-abi` major.

## Operational

- Tree clean at start and end but for the one added note; `ailang.lock` reverted after
  `sync_packages`.
- The stdlib cache was archived to scratchpad before clearing and restored afterwards — the two-sided
  demonstration, and the reason the 230-file state could be measured at all.
- `~/.ailang/cache/registry` left alone throughout, per S9's WI-C5 warning.
