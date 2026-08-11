# 2026-08-05 Cluster 28: WI-D4 — the three targets restored, and the conflation had a third channel

## Context

Branch: `arniwesth/mot-66-close-acceptance-row-10`.

Session span: `e129ac1` → **no commit; 15 modified source files plus a NOTE, working tree dirty by
request**. Input was `HANDOFF-execute-d4-restore-the-three-targets.md` (`169fa43`), executed against
HEAD. Twenty-eighth code session of project 009. Pin **v0.33.0**.

**Window: ~3h25m**, `19:57Z` → `21:22Z`, including a blocked interval described below.

**GROUNDING WAS NOT CLEAN, and this is the first finding.** A *second Claude Code session* had a
`make dst` running in this same working tree at session start — sharing the per-directory `.ailang`
caches and `/tmp/corpus_pr.out`, which both `corpus_pr` recipes write and then grep. Every measurement
this item exists to take would have been silently corrupted. I stopped my own run, asked the user
rather than killing another session's work, and waited. Its exit-2 red set then served as an
independent confirmation of the baseline, which is the one good thing to come of it.

The tree also carried **uncommitted WIP** — a partial `smoke_parity` candidate from the review
session. It was stashed for the baseline, then adopted with two corrections.

| Definition-of-done item | State |
|---|---|
| `seeded_generator`, `corpus_pr`, `smoke_parity` all green | **met** |
| `make dst` back to its two pre-existing red targets, failing set stated | **met** — `test_coverage`, `test_coverage_selftest` |
| `corpus_pr` printing its class-coverage rows, checked separately from exit code | **met** — and the handoff's account of why they were absent was wrong |
| The conflation fixed, not padded | **met** — and it had a channel the handoff did not name |
| The world-successor question answered per site, load-bearing ones named | **met** — 3 of 4 not load-bearing, 1 is |
| Zero-mismatch measurement owed at three further sites before the substitution | **met** — 657 executions, whole gate, 0 mismatches |
| S13 sweep cache-cold with `AILANG_RELAX_MODULES=1`, member-for-member | **met** — 226/17 of 243 |
| S9: every live cache cleared, `~/.ailang/cache/registry` untouched | **met** |
| S17: restore by `cp` | **met** — instrumented `session.ail` restored by `cp`, verified clean |
| Claiming C4's table is the NEXT item's job | **met** — obstruction removed, claim not made |

## THE ANSWER

**All three targets are green. `make dst` is back to two red targets.**

| | D3 | D4 |
|---|---|---|
| `make dst` red targets | 5 | **2** (pre-existing since B2a) |
| ✓ rows | 745 | **845** |
| Whole-tree sweep | 226/17 | **226/17**, member-for-member |
| `corpus_pr` class-coverage rows | RED | **GREEN, and printed** |
| `resolve_context_limit` sites on a run's path | 8 | **1** |
| `driver_only` | v9 | **v10** |

## THE HANDOFF WAS WRONG ABOUT TWO THINGS

### 1. `corpus_pr`'s class rows were never missing — they were RED

The handoff (and D3's corrected summary above it) reports that `corpus_pr` aborts *before* printing its
class-coverage evidence, so rows 4 and 11 "did not fail; they went missing."

**`main` runs every scenario before `exit(1)`.** The rows were produced on every run. They are absent
from the *make transcript* because the recipe's failure path is
`grep -v '^{' /tmp/corpus_pr.out | tail -40` — a 40-line window they scroll off. The artifact carried
them throughout:

```
✗ the corpus validates against 9 expected class(es): …
    [required-class-not-covered] no member of the fixed bank reaches
    required class 'ToolCorrelationMismatch'
✗ every expected class was OBSERVED (declared ⊆ observed)
    declared but never observed: ToolCorrelationMismatch
```

**This is worse than the handoff's reading.** "Unclaimable for want of evidence" is bookkeeping. A
required fault class that no member of D11's blocking bank reaches is a coverage regression.

**Two sessions read a truncated transcript as an absent artifact.** That is the generalisable part.

### 2. The conflation has THREE channels; the handoff named one

**Channel 1 — the budget.** `ports.ail:982` passed `List.length(state.log)` as `interactions_so_far`
and `dst_generator.ail:588` spends `max_interactions` against it, so driver env reads consumed the
generator's budget and truncated trajectories.

**Channel 2 — THE SALT, which is the one that hid.** All three generating seams salted every choice
with `n=${List.length(state.log)}` — `ports.ail` 932 and 1025, `stub_step.ail` 481. The driver's config
reads therefore **changed which branch every generated choice took**, not merely how many were allowed.

**A generated trajectory was a function of how often the driver read its configuration.** That is why
D3 silently reshuffled the entire fixed bank, why `seeded_generator` was red on **six** checks rather
than one (`tool faults=0`, `tool=0`, `reads=0` are starved trajectories, not check-fidelity problems),
and why removing the re-resolutions made `rich` **shorter** (provider 5 → 2) rather than longer — which
is the observation that sent me looking at the salt.

**Channel 3 — the assertion's `3 *`**, the one the handoff named, and the least of the three.

## What was done

**The measurement, taken before the substitution.** 657 site executions across the whole of `make dst`,
**all four sites reached, zero mismatches** — `CallModel` 282, `RunTools` 205, `AwaitApproval` 95,
`Finalize` 75 — comparing both the stored limit against a fresh resolution and the loop's `model`
against `policy.step.model`. D3 owed this at three sites and said so. Structural reason they agree:
every `session_policy_init` caller passes the same model it passes the loop, and the one model switch
rebuilds the policy through `session_policy_with_model` and passes both.

**The four successor answers.** Three not load-bearing; **the approval site is**. `post_ctx` was `post`
advanced past the resolution, and `post` is `st` advanced past the **approval read** — collapsing to
`st` type-checks and freezes the queue, which is WI-D1's production defect in reverse, in exactly the
population the handoff said to look at. Collapsed to `post`. The two sibling finalize sites return to
`st.world_state`, where they stood pre-D3; that is not a narrowing, because with no resolution in the
arm there is no widening to preserve.

**The conflation fixed at the source.** `dst_interaction.generator_authored_count` counts the three
kinds the generating adapters answer by CHOOSING, derived from `identity_kind` rather than three string
literals, and replaces `List.length(state.log)` at the budget and all three salts. The `3 *` is gone
and the relationship it hid is asserted exactly: `authored == budget + 1`, because the request that
spends the budget is answered by terminating and that terminator is itself authored. Two new rows —
an **S16 guard** (the count must be non-zero *and* strictly below the raw log length, since
`budget_spent` and the check now share a producer) and a **tightening row** (the literal must be below
the seed's natural trajectory, measured in the same run).

**`smoke_parity`.** A scripted run reads the catalogue from the **world**, D3's answer kept.
`run_v2_with_scripted_world` takes a whole `WorldState`; the fixture declares `test/tiny: 100`.
Seeding by default was refused — reading the host at construction is C1b in a hat, and a *hard-coded*
default is no better because every DST fixture resolves 0 precisely **because** its model is absent, so
any default changes them. No delta to report because the option was refused, and **no ambient
fallback** was added. `run_v2_with_scripted_ports` now genuinely **delegates**, which the adopted WIP
claimed and did not do; its inherited "eighteen call sites" is, measured, **thirteen**.

**Two re-derivations, not relaxations.** `rich` 77 → **110** and `pairB` 176 → **12** after sweeping all
260 seeds. `corpus_pr`'s fixed bank re-derived exactly as WI-D1 re-derived it: only seeds 1 and 5
survive and neither for its old reason, 13 members → **15**, every one load-bearing under the unchanged
selection rules. Class counts all moved; the partition did not.

**Cost constants re-measured, not raised.** `measured_ms_per_seed` **292 → 381** over 100 seeds built —
the old constant was measuring a generator that had been quietly truncated. All arithmetic over it
moved with it: `5000/381 = 13` affordable against a minimum of 12, **which fits by one seed rather than
five**, and the site says so plainly. `pr_target_ceiling_ms` **45000 → 80000**, set from the slow end of
an observed 24–50 s range at the previous pair's headroom ratio.

**The census, which S1 caught.** `discovery` and `strict_replay` went red on D3's per-scenario counts:
**12/12/12/19/8 → 1**. The parameter stays despite every caller passing the same number — what makes
the answer 1 is a property of the driver's call graph, and folding it into a constant would express
"this cannot differ", the claim D3 measured to be false.

**Anchor cascade paid once (S18).** `session.ail` 2654 → 2677 and 2764 → 2787, no judgement available
(still exactly four `ports.clock_now(` sites). Three consumers including the `anchors.sh` copy D3 found
the hard way. `driver_only` re-issued **v9 → v10**. **D3's historical record left as D3 wrote it**,
including its "eight call sites" — S15's trap is exactly a bare number re-dated inside a historical
record.

## Sites where two answers type-checked and one was silently wrong

**ONE, in the tree** — the `AwaitApproval` collapse. Not shipped; caught by reading the arm's own
comment before editing, which is S1's argument for that comment existing. **Counter is 55.**

**Determinism has caught none of the fifty-five, and here it would have been actively misleading.**
The generator was perfectly deterministic throughout: same seed, same trajectory, every run. It was
deterministic and **wrong**, because the function it was deterministic *in* included the driver's
environment surface.

Recorded separately and not counted: the seed sweep that recommended seed 1 graded the **generated**
witness where `axis_s7` grades the **replayed** one. It type-checked, ran, and produced a confident
answer the gate rejected on the next run — S1 working, and a second instance of D3's "a derivation
whose input is wrong disagrees with the literal it checks", one layer out.

## Corrections owed to the plan

1. **S19 extends to a gate's own REPORTING PATH.** A recipe that shows less on failure than on success
   has an inventory only on the happy path. *"Check the artifact, not the transcript."*
2. **A seeded generator's INPUT SET is part of its contract, and nothing guarded it.** "Same seed, same
   program" was true while "the program is a function of the seed" was false. *"Assert what a
   generator's output is a function OF, not only that it is a function."*
3. **A re-derivation must be graded by the gate's own predicate on the gate's own subject.**
4. **Concurrent sessions in one working tree are a measurement hazard** — shared caches and hard-coded
   `/tmp` paths. Suggested addition to S9: *"check that nothing else is running a gate."*
5. **The plan still has no item after Milestone C.** C4's planning defect 1 stands.

## Still owed

The two sibling `st.world_state` finalize sites — the audit's cheap answer is **reported rather than
taken**: `chain.next_state` is the pre-step chain's successor, so both finalize from a world predating
the extension chain's effects, the same shape as WI-D1's defect. Plus the `on_budget_plan` ABI change,
D3's decisions 6 and 9, D4's provider latency pair, the adversarial partial stream, the
`motoko-ext-abi` major, the `ailang iface` MOD010 filing, the 7 `TC_ARITY_001` scripts, the two
v0.33.0-fixed workarounds.

## THE NAME

**The obstruction to C4's table is removed. The claim is NOT made here.** Rows 4 and 11's evidence is
green and printed; rows 7 and 10 were green throughout; nothing here touched the other seven or re-ran
the table.

Three things the next item must not inherit as settled: **the env census moved to 1 across the board**,
**`driver_only` is v10**, and **rows 3 and 5 remain vacuous** in their installed-extension clauses.

**Twelve items have now declined the name and this is the twelfth.**

Full working note: `.agent/projects/009_motoko_dst_execution/NOTE-d4-restore-the-three-targets.md`.
