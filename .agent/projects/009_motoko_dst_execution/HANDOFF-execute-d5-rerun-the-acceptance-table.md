# Handoff: WI-D5 — re-run the acceptance table, and decide the name

Audience: a fresh session grounded against HEAD. **This item runs a gate and builds no evidence.**
Producing new machinery here is a symptom that something went wrong — the same rule C4 ran under.

**WI-D4 landed 2026-08-05** (~3h25m): the three targets D3 reddened are green, `resolve_context_limit`
is down from 8 sites on a run's path to 1, and the generator's salt no longer counts driver
interactions. Verified at review: **`make dst` exit 2 with only `test_coverage` and
`test_coverage_selftest`** — the two pre-existing since B2a — **845 ✓ rows**, sweep 226/17, and
`corpus_pr`'s class rows **green and printed**, nine classes with `every expected class was OBSERVED`.

**Check `git status` before anything.** At the time of writing D4's source work was **uncommitted** —
16 modified files. **A verdict measured against an uncommitted tree describes something no revision
records.** If it is still uncommitted, that is the first thing to resolve, and it is not this item's
call to make silently.

**Read first:** `NOTE-d4-restore-the-three-targets.md`, then `NOTE-c4-name-adoption-gate-verdict.md`
— **C4 is the item you are repeating**, and its eleven-row structure is the deliverable's shape. Then
**`ADR-001:2132-2155`**, the acceptance table itself. Then the plan's `## Standing rules`; **S20 is
new and it is why D4 existed.**

## Mission

**Run the eleven rows again, record the verdict, and if all eleven hold, decide the name.**

D10 has two conditions and only one is outstanding:

1. **the acceptance test passes for a documented baseline profile** — C4 found ten of eleven; D1, D2
   and D3 closed the four that were red; D4 restored the evidence for two of them. **Nobody has run
   the table since C4.**
2. **project-007's definition/taxonomy ADR is accepted** — **`Accepted 2026-07-26`.** Satisfied for
   weeks. Confirm it, do not re-litigate it.

## The rule you will break by accident

**D10 adopts the label for the AXIS, and the baseline profile passes two of its rows VACUOUSLY.**

The wording is *"the unqualified 'DST'/'simulation' label is adopted **for the generated axis** only
after the acceptance test passes **for a documented baseline profile**… additional profiles earn
**coverage** separately."* So one profile's green table earns the label for the whole axis; what
additional profiles earn separately is coverage, not the name.

**And `driver_only` passes rows 3 and 5 only because it installs nothing.** Every clause of the
boundary row quantifying over installed extensions ranges over the empty set. Row 5's clock claim is
real but its transferability is not — compose's eight clock reads sit outside the profile's reach
solely because nothing is installed. B4 proved the empty install list is *forced*: no extension is
installable under D5 while `on_budget_plan` carries the ABI's closed `! {Env, FS}` row.

**So the question this item must answer out loud is whether a baseline that covers no extension can
earn an axis-wide name.** The ADR's text says a documented baseline profile, and `driver_only` is
documented and is the baseline — so the textual answer is yes. **Do not let that be the whole
answer.** Whatever you decide, the verdict must state that **the axis's extension-model coverage is
zero and that this is structural rather than incidental.** A green table that reads as "Motoko has
DST" without that sentence is the one outcome twelve items of discipline were protecting against.

## The adoption surface, measured — it is small, and it is not a rename

**There is no rename cascade waiting.** 007's ADR grandfathers every existing `dst` identifier — the
`dst` and `dst_seeded` targets, module names, PASS labels, workflow text, the as-built title — and
says the exception *"prevents churn; it does not confer the new meaning."* **Every target project 009
added already uses a non-simulation working name**: `attribution_table`, `corpus_pr`, `driver_only`,
`ledger_parity`, `stream_parity`, `world_state`, `seeded_generator`, `declared_vs_performed`,
`hook_guard`. Twelve items kept that discipline. **D10's adoption permits the label; it does not
require renaming anything.**

**What it does change is the public record**, and there is one document:
`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`. It currently states the distinction
in three places — that what is built *"does not yet meet that ADR's conformance bar"* (`:8`), that the
axis is *"strictly stronger than trace replay, strictly weaker than DST"* with an *"interim name"*
(`:46-47`), and that the deterministic test world *"would earn the DST name"* as **known deferred
work** (`:292`). **If the verdict is green, that document is where the adoption is recorded**, and per
S15 the superseded sentences are restated with their date rather than deleted — they are history, and
they were true.

## Stale inputs — do not inherit C4's numbers

C4's verdict document is the shape to follow and its **figures are three items out of date**:

| C4 recorded | HEAD |
|---|---|
| `driver_only` **v7** / `driver_only/7` | **v10** |
| env resolutions per scenario 12/12/12/19/8 | **1 across the board** |
| `d64_gap_register` 13 | **2** |
| corpus reaching 5 of 9 required classes | **9 of 9** |
| ✓ rows 805 | **845** |

**Re-derive every row's evidence from a run you make.** Reading C4's answers forward is the failure
this project has recorded twice in three items — a headline true when written and false at HEAD.

## Definition of done

**Eleven rows, eleven answers, each with the evidence that produced it** — and the two vacuous passes
marked vacuous, distinctly from the nine real ones.

**The verdict, and the name decision with its reasoning.** This is the item's durable output. **A NO
remains a legitimate outcome**; so does a YES with the coverage caveat stated. What is not legitimate
is a YES that does not mention what the baseline does not cover.

**If YES: the as-built document updated**, with the superseded claims dated rather than deleted, and
the profile named — D10 requires that every report names the profile.

**Per S13 — a whole-tree sweep cache-cold with `AILANG_RELAX_MODULES=1`**, failing set confirmed
member-for-member against the expected seventeen. **And run `make dst` in full**: D3's regression was
found by nothing smaller, and three of D4's four targets were outside the obvious verification set.
**Per S9 — clear every live `.ailang/cache`, leave `~/.ailang/cache/registry` alone, and check that no
other session is running a gate in this tree** — D4 found one and every measurement would have been
poisoned silently.

**Per S19 — read the artifacts, not the transcripts.** `corpus_pr` writes `/tmp/corpus_pr.out` and
prints only `tail -40` of it **on failure**; two sessions in a row misread that, this reviewer
included. Any row whose evidence comes from a `make` log is a row read from a lossy channel.

## Out of scope

- **The `on_budget_plan` ABI change.** It is the only substantive item left and it is what would make
  the two vacuous passes non-vacuous — but it is a second ABI major with a profile bump behind it, and
  running the gate is this item's whole job.
- **A second profile.** Additional profiles earn coverage separately and none exists.
- **The two sibling `st.world_state` finalize sites**; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `motoko-ext-abi` major; the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two
  v0.33.0-fixed workarounds.

## Stop and report rather than deciding inline

- **If a row that C4 passed now fails**, stop and report it as a regression with its cause. Three of
  the last four items moved a red set, and two reported it incompletely.
- **If answering a row requires building anything**, that is a planning defect to name, not an
  experiment to run here — C4's rule, and it held.
- **If the name decision turns on a reading of D10 you have to argue for**, report the reading rather
  than taking it. Twelve items have declined this name; the thirteenth adopting it on a contested
  reading of one sentence would be the weakest possible ending.

## Report back

Twenty-ninth calibration run, and the one the project has been walking toward.

- **The git wall-clock window.**
- **The eleven answers**, with vacuous passes marked and every figure re-derived rather than inherited.
- **The verdict and the name decision**, with the coverage caveat stated either way.
- **`make dst`'s full red set** and the sweep's failing set, member-for-member.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **55 across
  twenty-eight runs; determinism has caught none** — and per S20, D4 established that determinism can
  be *actively reassuring* while the property it appears to confirm is false. This item writes no
  production code; if it counts one, say why.
- **What is left.** If the name is adopted, say what the label does and does not now assert, and name
  the one item that would make it transfer.
