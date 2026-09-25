# 2026-08-09 Cluster 51: WI-D25 — the successor audits, `on_pre_step` and `on_solver_candidate`

## Context

Branch: `arniwesth/mot-87-wi-d25-the-successor-audits-on_pre_step-and`.

Session span: `f548834` → **working tree, uncommitted**. Input was
`HANDOFF-execute-d25-the-successor-audits.md`, grounded against HEAD `f548834`
(`2026-08-09T12:54:57Z`). Pin **v0.33.0**. Work complete at ~`13:50Z`, **~1h10m**.

**Item 3 of the goal line's six-item critical path**, and the last audit S29 requires before item 4
routes anything. 10 files, **412 insertions / 25 deletions** (the NOTE is a new file, 374 lines):

```text
.agent/.../NOTE-d25-the-successor-audits.md              374 +  the record (new)
.agent/.../PLAN-implementation-...md                     101 +- item 3 ✓, S29's record corrected,
                                                                the D25 milestone, register + 1
scripts/dst/world_state_probe.ail                        118 +- consume_steps + two performing
                                                                on_pre_step bindings; six seal rows
scripts/dst/run_declared_vs_performed.sh                  78 +  port_accepts/port_rejects: the four
                                                                capability verdicts + two controls
src/core/ext/runtime.ail                                  28 +- three false seam claims corrected,
                                                                two-part per S15
src/core/session.ail                                      27 +- the two c2_finalize arguments; WI-D4's
                                                                expired scope clause re-tensed
the anchor cascade (4 files)                              60 +- two anchors, driver_only 21→22,
                                                                no_ops 8→9, hash re-derived by running
```

**The tree is left uncommitted.** Nothing was committed or pushed this session.

## What the audit found — seven arms, one drop

**`on_solver_candidate`** — `dispatch_solver_candidate` has **one** production call site
(`session.ail:2800`; census re-derived per S22). `FinalizeDecision` has three variants but **four**
consuming endpoints, because `NoDecision` branches on the persist-nudge policy — `:2803`, `:2814`,
`:2846`, `:2863`. **All four thread.** Read side clean on both counts: D19's
`{ post_ctx | world: intercepted.next_state }` re-seat on the way in, and
`collect_finalize_decisions` threads the hook list with an explicit `let` (deliberately not
`decide_one(…) :: collect(…)`, whose evaluation order would be a silent ordering assumption on a
cursor) while `decide_one_finalize` re-seats `ctx.world` per hook.

**`on_pre_step`** — one production call site (`session.ail:2537`), one arm of three. The two `Err`
arms of `seal_compacted_payload` passed `st.world_state` to `c2_finalize` while `chain.next_state`
existed. **This was WI-D4's documented deferral**, named in a comment at the site.

**No unknown drop in either path.**

## The four findings worth carrying

1. **A deferral's stated scope is not a reason — re-derive it when the scope arrives.** WI-D4's
   justification for the two seal arms is entirely about *its own deleted resolution* and says
   nothing whatever about the chain. The chain is dispatched **below** that comment and **above**
   the match, so a pre-step hook's effects have already happened on all three arms when the seal
   decides. Sealing failed; the effects did not. Both arms now take
   `token_to_world(chain.next_state)` — a line-count-neutral argument swap — and the expired clause
   is quoted before being answered, two-part per S15. This is S22 applied to prose, and it is
   promoted into S29's plan text.

2. **D24's row algebra was still live in three source sites.** The plan's D24 milestone was
   corrected at the D25 handoff; `ext/runtime.ail` was not. `:272` (*"Three of the seven slots
   can"* — **two** can), `:394` (*"one of the three"*), `:442` (*"`! {Process}`, so this slot
   reaches the seam too"* — it does not). `proc_exec` demands the whole row `{IO, Process, FS}` and
   `on_solver_candidate` declares `! {Process}` alone: the slot **contains** the effect and cannot
   reach the seam that needs it. "Can" was inferred from **presence**, not **inclusion** — S33's
   shape, in a reviewing role. `first_intercept`'s claim is true and was left alone.

3. **The capability bounds are executable now, not prose.** Four compiler verdicts in
   `run_declared_vs_performed.sh` (`port_accepts` / `port_rejects`), each rejection paired with a
   widened control so it is attributable to the row rather than to a malformed call:

   ```text
   ✓ on_pre_step -> ports.ai_step:            ACCEPTED under ! {AI, IO, Trace}
   ✓ on_pre_step -> ports.clock_now:          REJECTED (Missing effects: Clock)
   ✓ on_solver_candidate -> ports.proc_exec:  REJECTED (Missing effects: FS, IO)
   ✓ on_solver_candidate -> AMBIENT std/process.exec: ACCEPTED under ! {Process}
   ```

   `on_pre_step` reaches **1 of 10** `ExtPorts` fields; `on_solver_candidate` **0 of 10**. These are
   disclosure-table rows (goal-line clause 2) and the audit's most durable output.

4. **The cascade narrows the six-file law the way D24 narrowed the nine.** `session.ail` +21 inside
   `c2_loop`'s `CallModel` arm, which sits **below `:1476`** and **above** the two
   `provider.ports.clock_now` sites — so only `2921→2942` and `3031→3052` moved, both
   byte-identical against `git show HEAD:`. **The first re-issue where the five session anchors
   move as a proper subset.** `ext/runtime.ail` grew entirely below its `:199` anchor, so the
   fixture-carried pair is unmoved. **Five files, not six**, because
   `scripts/dst/attribution_table_dst.ail` needed no edit: its only session anchor is `:1476` and
   its HEAD inventory is DERIVED (`head_inventory()` calls `unconditional_core_sites()`). The rule,
   recorded in `anchors.sh`: **the cascade's width is the set of files that PIN the anchors that
   moved, derived by the widened grep, not read off which file was edited.** D21 read it off the
   edited file and was wrong twice — nine when `tool_phase` was untouched (D24), six when
   `attribution_table_dst` was untouched (here).

## The witness and the mutant

`consume_steps` + `consuming_pre_step_2`/`_3` in `world_state_probe.ail` are **the first
`on_pre_step` bindings in this tree that perform**. That is exactly S29's invisibility clause met
head-on: both seal terminals were **already driven** in this file — the env row drives
`SealSystemPromptEmpty`, the files row drives `SealExhausted` — and both were green **across the
drop**, because every binding returns `ctx.world` unchanged and a drop then produces a world
byte-identical to a thread.

`ai_step` is the *only* seam the row admits (finding 3), and it threads the provider seam, so under
a scripted world each call takes the head of `WorldState.script`. What is **left** in the terminal
world is a quantity the driver's own bookkeeping never writes — **6−2=4** and **5−3=2**, S7-distinct
across both scenarios. Six rows, three per terminal: the threading count, a **reachability** row
naming the terminal actually taken (S24 — a run that sealed successfully leaves the script whole
too, which is byte-identical to the drop), and a **control** with `passthrough_pre_step` proving the
count is the hook's and not the driver's.

**The mutant** (revert both arguments; restore by file copy per S17) kills **exactly the two
threading rows** and leaves the four reachability/control rows green.

**The solver slot gets the narrowed label and NO fixture, deliberately.** With zero reachable ports
a hook there cannot change world content, and a fabricated token dies at the next `token_to_world`
— S34's total-decoder fact met from the other side. A row that passes whether or not the threading
is correct is worse than no row (S33), so the four arms are verified **by reading,
source-anchored**, and said so. D20 §8.2's precedent and wording reused.

## S29's record, corrected honestly

> Four slots audited. Two audited **late**, after routing, and both dropped (D19, D20). Two audited
> **before** routing, here: `on_solver_candidate` on all four arms, `on_pre_step` on one of three,
> and the two drops were a documented deferral disclosed at the site rather than an unknown drop.

**The credit is split rather than claimed.** The solver slot came back clean largely because
**D19's intercept work re-seated it in passing** — the one re-seat that matters is D19-tagged, not
a fresh catch by the rule. What the rule earned is the `on_pre_step` half: the drop was written down
at its site by the item that deferred it, so the audit found it by *reading*. The rule changed the
observability; D19 changed the code.

## Counters and sweep

**Silent-wrong 75 unchanged; instrument-weaker-than-its-claim 7 unchanged.** The seal-terminal drop
was disclosed at its site and no performing `on_pre_step` hook exists in production at HEAD, so no
run ever shipped a wrong answer from it — a documented deferral is owed work, not a silent defect.
§4.2's narrowed label exists precisely to avoid becoming instance 8.

**One ruling left open for review rather than taken:** the three false seam claims shipped in source
and were contradicted by nothing, but they are prose rather than a value, so they were not counted
under silent-wrong. If review reads a shipped-and-wrong source claim as countable, that is the site.

Green by run: `world_state` (incl. all five poison pairs), `discovery`, `execution_program`,
`program_persistence`, `declared_vs_performed` (**46 passed, 0 failed**), `conformance`, `anchors`,
`predicate_anchors`, `attribution_table`, `profile_definition`, `profile_coverage`. Full `make dst`
red only on the two standing `test_coverage` targets. Yields and inventory asserted unmoved —
HOOK-PORT-MEDIATED 5/15, shipped closure verdict 4/15, ambient PORT-MEDIATED 4/15, compose 11/32,
`ext_call_inventory` reachability 10 derived = 10 pinned. Profiles **22 / 9**;
`sha256:4339fef0… → sha256:753839ba…`, derived by running `table_content_hash()` rather than
transcribed. `make sync_packages` not run and not owed — `types.ail` untouched.

**A THIRD standing red is disclosed rather than absorbed.** `make effect_inventory_selftest` fails
with *"the self-test compared ZERO modules, so it certified nothing"* — `ailang iface` yields no
parseable interface in this checkout, so the textual fallback is the only derivation in play and is
unvalidated. **Verified red at HEAD with the item's changes stashed.** It is the gate refusing a
pass-shaped absence, correctly, and it is not one of the two reds the register carried
(`test_coverage`, `test_coverage_selftest`, pinned since D22). Added to the maintenance register; it
blocks neither goal-line clause.

## What item 4 (routing compose's `exec` sites) inherits

**Nothing in these two paths constrains where the routed calls may land, and that is now a compiler
verdict rather than a reading.**

- `on_solver_candidate` **cannot host a routed `exec` at all** — zero reachable ports. Compose binds
  it (`compose.ail:1041`) and any `exec` in that binding stays **ambient** until the row widens,
  which is the barrier question (D7's three barriers stand), an ABI event, and off the critical path.
- `on_pre_step` has no `Process` at all.
- The two slots that **can** are `on_tool_handle` and `on_response_intercept` — both already routed,
  both already audited (D19, D20), and both reached by D24's identity work. Item 4's landing sites
  are exactly the two it already has.
- The seal-terminal fix cannot interact with item 4: it is a terminal arm with no tool dispatch
  downstream.
- **The one thing to carry forward:** `post_ctx.ports` at `session.ail:2679` is built from
  `st.world_state` and is stale relative to `exchange.next_state`. Unreachable today at the solver
  slot, and **live the moment anything widens that row** — D20's read-side defect in a second place,
  waiting for its first caller. Named at the site rather than fixed, because fixing it now would be
  a change no row can turn red.

**Owed and unchanged:** C5's compose-bearing profile (item 5) is still the debt every report since
D19 names; the solver slot's threading claim is fixture-less until then and beyond.
