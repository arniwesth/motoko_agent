# Handoff: WI-D4 — restore the three targets D3 reddened, before the table can be re-run

Audience: a fresh session grounded against HEAD. Source-heavy driver work; you are that session.

**This item exists because WI-D3 shipped a regression and said so — partly.** It named two red targets
and deferred their repair with a measurement. **A third went red and is unreported.** Nothing here is
a criticism of D3's core work: row 10 closed, five two-sided poison pairs hold, and the filesystem
class is right. The routing simply had a blast radius one target wider than the item measured.

**Read first:** `NOTE-d3-filesystem-world-class-row-10.md`, especially *"TWO TARGETS ARE RED"* — its
analysis of the cause is correct and is most of your first repair. Then the plan's `## Standing
rules`; **S13 and S16 both grew at D3.**

## The state, measured at review rather than taken from the report

**`make dst` exit 2 with FIVE red targets**, not the two this series has carried since B4:

| Target | Status | Named by D3? |
|---|---|---|
| `corpus_pr` | red | yes |
| `seeded_generator` | red | yes |
| **`smoke_parity`** | **red** | **no — zero mentions** |
| `test_coverage`, `test_coverage_selftest` | red | pre-existing since B2a |

**✓ rows fall 831 → 701**, because an aborting target stops *producing* rows rather than reporting
failures. The whole-tree sweep is unaffected at 226/17.

**AND C4's ACCEPTANCE TABLE IS NOT GREEN.** D3 reports eleven of eleven; that was true at D2 and is
not true at HEAD. **Rows 4 and 11's evidence is produced by `corpus_pr`, and `corpus_pr` currently
produces none** — it aborts at the WI-A15 commit gate *before* printing
`the corpus validates against N expected class(es)` or `every expected class was OBSERVED`. Both
strings are **absent** from the output. The rows did not fail; they went missing. **Rows 7 and 10 are
genuinely green.**

## Mission

**Restore `seeded_generator`, `corpus_pr` and `smoke_parity`, and fix the conflation the regression
exposed.** Only then can C4's table be re-run and mean anything.

## Three failures, three causes — and the third contradicts D3's stated basis

**1 and 2 — `seeded_generator` and `corpus_pr`: one cause, and D3 named the repair.**
Routing `context_usage` put the driver's config reads into the recorded interaction log. Each
`resolve_context_limit` performs five env requests and the driver re-resolves a static value on every
loop arm, so a run carries 15–95 interactions no generator authored. Confirmed at review:
`the bounded run recorded 24 interactions against a declared budget of 6`, and `env_missing=50`
dominating the S7 distinctness set.

**The repair: the four `c2_loop` sites read `policy.step.compaction.context_limit` instead of
re-resolving.** Eight call sites exist — `rpc.ail:116,226` (ambient, empty world),
`session.ail:1638,1674` (policy init, which *store* the value), and **`session.ail:2034, 2144, 2188,
2262`, which are the four that recompute it.** D3 measured **zero mismatches** at the `CallModel` site
across `world_state`, `discovery`, `strict_replay` and `compaction_dst`. **That measurement is owed at
the other three before you take it** — D3 says so and it is the honest condition.

**3 — `smoke_parity`, and this one has a counterexample to D3's justification.**
`scripts/smoke_v2_compaction_full_loop.ail` drives the **scripted** world through
`run_v2_with_scripted_ports`, and its compaction depends on `test/tiny`'s context limit — **which is
in `.motoko/model-catalog.json` at 100.** With the read routed and the fixture's `files` table empty
it resolves to **0**, compaction never fires structurally, and the parity harness's
`grep -q '"type":"compaction_extension".*"note":"structural:'` finds **zero** where it requires one.
The adjacent `msg_count":14` assertion still passes, so the target fails on one clause of two.

**D3's stated basis was:** *"The DST fixtures did not depend on the VALUES — their models are absent
from the catalogue and resolve to 0."* **`test/tiny` is not absent.** The claim held for the fixtures
checked and one was not checked — **S13 in a new place: `world_state`, `discovery`, `strict_replay`
and `compaction_dst` were all run and all pass; the target that broke is one none of them covers.**

## The rule you will break by accident

**Removing the four `resolve_context_limit` calls also removes four world successors, and that is
D1's exact defect in reverse.**

Each site reads:

```ailang
let r_limit = resolve_context_limit(context_reader_of(st.provider), st.world_state, model);
let st_ctx: C2LoopState = { st | world_state: r_limit.next_state };
```

`st_ctx` exists **only** to carry the successor forward, and the scripted seams genuinely advance the
world — they call `record_interaction`, which is why the log inflated at all. So this is not an
identity transition being tidied away; it is a real successor disappearing along with the reads that
produced it.

**Before deleting `st_ctx`, check every use of it below each site.** WI-D1 found a production defect
of exactly this shape — `c2_finalize` finalizing from `st.world_state` when `exchange.next_state` was
the live one — and it was invisible to every gate until a fault class needed the log entry. **S12
governs: an identity transition is correct for a component that did nothing and a silent defect for
one that did something, and no type distinguishes them.** If a site's `st_ctx` is used after other
work that advances the world, collapsing it to `st` throws that work away.

## `smoke_parity`'s design decision, which is yours

**`run_v2_with_scripted_ports` cannot carry a file table.** Its parameters end at `script:
[ScriptedStep]`, and it hands `Scripted(script)` to `run_v2_from_messages`, which lets
`ported_provider` build the world. **There is no seam through which a fixture can seed `files`.**

So the question is genuinely open and it is a conformance question, not a plumbing one: **should a
scripted run read the model catalogue from the world or from the host?** D3's answer for the driver
was *the world*, and that is what closed row 10. The consequences differ by route:

- **Widen the scripted entry point to carry `files`** and seed `test/tiny` in the fixture. Keeps
  hermeticity, costs a parameter on an entry point with many callers.
- **Seed the catalogue into the deterministic world by default** in the scripted constructor. Cheaper,
  but a default that reads the host at construction time is the C1b defect wearing a different hat —
  **check whether it is, rather than assuming either way.**
- **Restore the value some third way.** Whatever you choose, **do not make the scripted file seam fall
  back to ambient on a miss.** D3 refused exactly that (its decision 2) and the reason is recorded:
  a file the world has no opinion about is the ambient dependency the class exists to remove.

## The conflation, which is the reason this recurs

`seeded_generator`'s bound is `List.length(squeezed.run.world.log) <= 3 * tight.max_interactions`
(`seeded_generator_dst.ail:738`). **The `3 *` was already absorbing driver overhead the generator
never authored** — the check compares a GENERATOR budget against a log the DRIVER also writes into.
D3 widened the driver's share until the slack ran out.

**Restoring slack makes the symptom go away and leaves the defect.** The honest forms are to count
only generator-authored interactions, or to state the driver's fixed overhead as a named measured
constant beside the budget. **Per S15, whichever you choose, record the measurement rather than the
diagnosis** — a constant with a number and the run it came from survives; "the driver adds some
overhead" does not.

## Definition of done

**All three targets green**, and `make dst` back to its two pre-existing red targets — with the
failing set stated, not implied.

**`corpus_pr` printing its class-coverage rows again.** They are rows 4 and 11's evidence and their
absence is what makes the table unclaimable. **Check the rows print, not just that the target exits
0** — per S19, this project has now been bitten four times by evidence that went missing rather than
red.

**The conflation fixed, not padded.** If you raise the slack, say so plainly as a deferral with the
honest fix named; do not let a widened constant read as a repair.

**The world-successor question answered per site.** Four sites, four answers, and say whether any
`st_ctx` was load-bearing.

**Per S13 — sweep cache-cold with `AILANG_RELAX_MODULES=1`**, failing set member-for-member. **And run
`make dst` in full**: three of this item's four targets are ones the obvious verification set does not
cover, which is how the third one was missed. **Per S9/S17** — clear every live `.ailang/cache`, leave
`~/.ailang/cache/registry` alone, restore mutants by `cp`.

## Out of scope

- **Re-running C4's acceptance table and adopting the name.** The next item, and it cannot run
  usefully until this one lands — the env census numbers D3 pinned move here.
- **The `on_budget_plan` ABI change** and everything gated on it.
- **The two sibling `st.world_state` finalize sites** (`SealSystemPromptEmpty`, `SealExhausted`) —
  still owed. **They are the same shape as this item's trap**; if your successor audit gives you a
  cheap answer for them, report it rather than fixing it here.
- **File reads in the interaction log** (D3's decision 6); **`FS` in
  `driver_only.forbidden_capabilities`** (its decision 9); D4's provider latency pair; the adversarial
  partial stream; the `motoko-ext-abi` major; the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001`
  scripts; the two v0.33.0-fixed workarounds.

## Stop and report rather than deciding inline

- **If the zero-mismatch measurement does not hold at all four sites**, stop. A site where the policy
  value and the freshly resolved value differ is a behavioural difference, not a refactor, and it
  means the driver was relying on re-resolution somewhere.
- **If seeding the catalogue into the scripted world changes what any DST fixture resolves**, report
  the delta before taking it. D3's fixtures resolve to 0 today *because* their models are absent, and
  a default that changes that changes their behaviour.
- **If a fourth target turns out to be red**, report it as a class rather than repairing it inline.
  Three were found across two sessions and the third took a full `make dst` to surface.

## Report back

Twenty-eighth calibration run.

- **The git wall-clock window.**
- **The three targets' final state**, and `make dst`'s full red set.
- **Whether `corpus_pr` prints its class rows**, stated separately from its exit code.
- **The four successor answers**, per site.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **54 across
  twenty-seven runs; determinism has caught none**, and D3's was in its own gate. This item deletes
  world-threading expressions, which is the population D1's production defect came from — look there
  deliberately.
- **Whether C4's table can be claimed green again**, and say plainly that claiming it is the *next*
  item's job, not this one's.
