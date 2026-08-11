# 2026-08-06 Cluster 29: WI-D5 — the acceptance table re-run, and the name adopted

## Context

Branch: `arniwesth/mot-67-wi-d4-restore-the-three-targets-d3-reddened`.

Session span: `5ecd858` → **`46d2b5a`** ("docs(009): apply D5 — the name is adopted, and S21 on
vacuity that concentrates") — the verdict NOTE, the plan record and the as-built document, committed
after the session's measurements were complete. **S21 was promoted from this item's correction 3 in
that same commit.** Input was `HANDOFF-execute-d5-rerun-the-acceptance-table.md` (`5ecd858`),
executed against HEAD. Twenty-ninth code session of project 009. Pin **v0.33.0**.

**Window: ~25 min**, `06:51Z` → `07:16Z`. Two measurements dominate it: the cache-cold sweep
(`06:53:18Z` → `06:56:36Z`) and `make dst` in full (`06:57:09Z` → `07:07:05Z`).

**Grounding was clean, and the handoff's first worry was already resolved.** D4's source work was
uncommitted when the handoff was written — 16 modified files — and the handoff correctly refused to
let a verdict be measured against a tree no revision records. **It had been committed in the
meantime**: `f2ca448` ("Impelmented"), the exact 16-file set, 736 insertions. `git status` clean.
Nothing was resolved silently because nothing needed resolving.

**S9's concurrency check found nothing, which is the point.** One live `ailang` process in the tree —
a `supervisor.ail` agent run, 1d09h elapsed against 447s CPU, holding no `.ailang/cache` or
`/tmp/*.out` descriptors. An idle agent session, not a gate. D4 was poisoned by exactly this class of
thing and had to stop and wait; this run had the check built into the procedure.

| Definition-of-done item | State |
|---|---|
| Eleven rows, eleven answers, each with evidence from a run I made | **met** |
| Vacuous passes marked, distinctly from real ones | **met** — and there are **four leaning rows, not two** |
| The verdict and the name decision, with reasoning | **met** — YES, adopted |
| Coverage caveat stated either way | **met** — made mandatory in the as-built doc, not optional |
| As-built document updated, superseded claims dated not deleted (S15) | **met** — three sites, plus a fourth stale clause nobody had named |
| The profile named (D10 requires every report to name it) | **met** — `driver_only/10` under manifest `driver_only/3` |
| S13 sweep cache-cold with `AILANG_RELAX_MODULES=1`, member-for-member | **met** — 226/17 of 243 |
| `make dst` in full | **met** — exit 2, red set exactly the two pre-existing |
| S9: every live cache cleared, `~/.ailang/cache/registry` untouched | **met** — 8 cleared, registry verified intact |
| S19: read artifacts, not transcripts | **met** — `/tmp/*.out` deleted first, rows 4/11/5 read from artifacts |
| Build no evidence / write no production code | **met** — two gates run, one document edited |

## THE ANSWER

**Eleven of eleven. The name is adopted for the generated axis, for one profile, with a mandatory
caveat.**

| | C4 | D5 |
|---|---|---|
| Acceptance rows holding | 7 of 11 | **11 of 11** |
| `make dst` red targets | 2 | **2** (`test_coverage`, `test_coverage_selftest`, pre-existing since B2a) |
| ✓ rows | 805 | **845** — identical to D4, same methodology |
| Whole-tree sweep | 225/17 | **226/17**, member-for-member |
| `driver_only` | v7 | **v10** under manifest `driver_only/3` |
| `d64_gap_register` | 13 | **2** (`ScratchpadResult`, `SessionSuspend`) |
| Fault classes reached by the bank | 5 of 9 | **9 of 9**, register empty |
| Env resolutions per scenario | 12/12/12/19/8 | **1 across the board** |
| Two-sided poison pairs | 3 | **5** |

**Nothing was inherited from C4.** Every figure above was re-derived from this session's own run —
the failure mode this project has recorded twice in three items is a headline true when written and
false at HEAD.

## THE FINDING: the vacuity surface is four rows, not two, and the fourth appeared *because* D2 succeeded

The handoff carried forward two rows passing vacuously — 3 and 5 — and asked that they be marked.
**There are four rows leaning on `driver_only`'s empty install list in a named clause.**

| Row | What the empty install list buys |
|---|---|
| 3 | **The pass is vacuous.** Every clause quantifying over installed extensions ranges over the empty set |
| 4 | The `extension_effect_fault` **waiver** — "driver_only installs none, so it waives this class by construction" |
| 5 | **Transferability.** Compose's eight unrouted clock reads sit outside reach only because nothing is installed |
| 7 | The `ScratchpadResult` **exemption** — no run emits it because no hook is installed to emit it |

**Row 7 is the new one, and the mechanism is worth more than the fact.** At C4 the register held
thirteen variants, **eleven of them `driver_only`-reachable** — which is exactly why C4 could write
that the row "fails under every reading of profile-reachable". The profile's emptiness bought nothing
there. **WI-D2 closed those eleven by appending them to the trace**, and what remains is a
two-element residue in which one entry is purchased by the empty install list.

**So closing a row concentrated a vacuity rather than removing it.** The proportion of row 7 that
rests on emptiness went *up* as the row got *better*. No gate sees this, and no rule in the project
tracks it: each individual caveat was recorded correctly in its own row's prose, and the count moved
from two to four with nobody noticing. It is visible only by asking, of each surviving exemption,
*why* it survives.

## THE ONE READING, REPORTED RATHER THAN TAKEN

**Row 7's third conjunct — "all logical ledger emissions appear in the returned trace" — is literally
false at HEAD.** Two of twenty-eight Logical variants do not reach the trace.

It passes on **WI-D2's recorded reading: *emissions that OCCUR reach the trace*.** Both survivors are
coverage gaps rather than parity gaps — no run in this tree emits them, measured rather than argued —
and the positive half is checked out of process, per variant, at **17 variants compared
wire-against-trace, every one equal**.

**This is not the narrowing C4 forbade.** C4 named two illegitimate one-line escapes: reclassifying
Logical variants as `DisplayOnly`, and shrinking `driver_only`'s declared reach. D2 did neither — the
pinned `DisplayOnly` baseline is still the same six, a row asserts by name that all eleven closed
variants are still Logical, and the profile's coverage claim is unchanged. D2 closed the row by doing
the work.

**But it is still a reading, and it is the table's single interpretive dependency.** Reject it and
row 7 is red and the verdict is NO. Stated in the verdict rather than buried, so a reviewer knows
exactly which row to reopen. The handoff's rule — *if the name decision turns on a reading you have
to argue for, report the reading rather than taking it* — is why this is called out; the **name**
decision does not turn on it, but the **table** does.

## THE NAME DECISION, AND WHY IT IS NOT A CONTESTED READING

**Adopted.** D10's text:

> The unqualified "DST"/"simulation" label is adopted for the generated axis only after the
> acceptance test passes **for a documented baseline profile** and the project-007 ADR is accepted.
> Every report names the profile; **additional profiles earn coverage separately.**

Both conditions are met: the table is green for `driver_only/10`, and 007's ADR is
`Accepted 2026-07-26` (confirmed, not re-litigated). **And the clause that would otherwise be the
objection — that this baseline covers no extension — is the clause D10 already anticipates.**
"Additional profiles earn coverage separately" says in as many words that one profile's green table
does not carry another's coverage. Declining on that ground would substitute a judgement for the rule
the ADR states.

**The mandatory caveat, now in the as-built document rather than only in a note:**

> **The axis's extension-model coverage is ZERO, and that is structural rather than incidental.**
> The empty install list is **forced**: while `ExtensionHooks.on_budget_plan` declares the ABI's
> closed row `! {Env, FS}` and returns a successor-free `BudgetPatch`, no extension in the tree is
> installable in a conformant profile.

**Adoption renamed nothing.** 007 grandfathers every existing `dst` identifier, and every target
project 009 added already uses a non-simulation working name. D10's adoption *permits* the label.

## Documents changed

**`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`** — the one public record. Three
superseded claims **restated with their date rather than deleted** (S15), because they were true when
written and a bare tense re-dated inside a historical record becomes a false claim about history:

| Site | Superseded claim |
|---|---|
| `:8` | what is built *"does not yet meet that ADR's conformance bar"* |
| `:46-47` | *"strictly stronger than trace replay, strictly weaker than DST"*, with an *"interim name"* |
| `:292` | the world *"would earn the DST name"*, as **known deferred work** |

**And a fourth stale clause nobody had named**: the deferred-work entry also said the work was
*"currently blocked on an upstream AILANG recorded-stream API"* — which landed in a released AILANG
and was repinned at B1, adopted at C1/C2. **Two halves of one entry expired at different times**, and
both are recorded.

**`PLAN-implementation-deterministic-test-world.md`** — a WI-D5 record after D4's, stating the
verdict, the four leaning rows, and the reading row 7 rests on.

**`NOTE-d5-acceptance-table-rerun-and-name-decision.md`** — the eleven-row verdict, C4's structure.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243.** Run
  **first**, per S13. Failing set member-for-member: 7 `TC_ARITY_001` smoke scripts, the
  sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture. Stable
  across B4, C1, C3, C5, C4, D3, D4 and now D5.
- **`make dst` — EXIT 2, red set `test_coverage` and `test_coverage_selftest`, and nothing else.**
  Both pre-existing since B2a. **845 ✓ rows**, identical to D4's under the same methodology, so the
  comparison is legitimate rather than invented.
- Every row producer green, including `hook_guard` (4/0), `declared_vs_performed` (10/0),
  `ledger_parity` and `stream_parity` wire gates (both out of process).

## Sites where two answers type-checked and one was silently wrong

**None. The counter stays at 55.** This item wrote no production code — two gates run, their
artifacts read, one design document edited. There was no site at which two answers could type-check.

**Determinism has still caught none of the fifty-five**, and per S20 this session is a clean case of
why: every figure here is reproducible, and reproducibility is precisely what D4 proved can hold
while the property it appears to confirm is false. **What makes these numbers trustworthy is not that
they reproduce D4's — it is that the generator's salts no longer count driver interactions, so the
quantity being reproduced is now a function of the seed.** A run reproducing D4's numbers *before*
S20 would have proved nothing at all.

## Corrections owed to the plan

1. **The plan has no item for this work, and now no item at all.** C4's planning defect 1 stands
   through D1, D2, D3, D4 and D5. The last item is **WI-C5**, unbuilt. **Five consecutive items have
   executed with no plan entry**, and this one closed the project's headline milestone that way.
2. **The plan's WI-C4 entry still has no YES branch.** The NO branch was added after C4; nothing says
   adoption is a documentation act with a mandatory caveat rather than a rename, which is why that
   had to arrive by handoff.
3. **A vacuity can migrate between rows when a row closes, and nothing tracked it.** **Applied as
   S21** in `46d2b5a`: *when a row closes, re-ask of every surviving exemption in every OTHER row why
   it survives — a closure narrows the set of reasons, and a reason that used to be one of many can
   become the only one.* No gate in this project can see this.
4. **"What the label does not assert" needs to be a checked artifact, not prose.** It is now
   load-bearing for every future report and lives in two paragraphs — exactly the class S15 says gets
   quoted forward and re-dated. The gate already computes everything it asserts; a row that printed
   the caveat would make a green table unreportable without it.
5. **S19 earned itself quietly again.** Rows 4, 11 and 5 were read from `/tmp/corpus_pr.out` and
   `/tmp/latency_pair.out`. They were green — but had they been red, the transcript would again have
   shown a 40-line tail they scroll off.

## What is left

- **The `on_budget_plan` ABI widening** — the one change that would make the four extension-dependent
  clauses non-vacuous. A second ABI major with a profile bump behind it.
- **A second profile** (WI-C5, `compose`-bearing). None exists.
- The two sibling `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `motoko-ext-abi` major; the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two
  v0.33.0-fixed workarounds.
- `test_coverage` and `test_coverage_selftest`, red since B2a, untouched here.

**Twelve items declined this name. The thirteenth adopts it, for one profile, on a green table of
eleven rows, and says in the same breath what that profile does not cover.**
