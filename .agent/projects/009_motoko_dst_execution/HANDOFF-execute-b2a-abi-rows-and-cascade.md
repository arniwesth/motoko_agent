# Handoff: execute WI-B2 part 1 — settle the ABI rows, then close the cascade

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-B3 landed 2026-08-04** (48m40s): zero `images` failures tree-wide, from 91. **The wall moved
rather than fell** — `make check_core` still exits 2, all seven extensions still failing on one
identical line, now `motoko_ext_compose.register_with_config`. Tree: **161 pass / 74 fail**.

**Read first:** `NOTE-b3-execution-report-and-plan-corrections.md`, then
`NOTE-b1-execution-report-and-plan-corrections.md`, then the plan's `## Standing rules` — **S9 and
S10 are both new and both bite here.**

## Mission, and why this is B2 split in half

**WI-B2 as written is two items, and only the first is forced.** The plan gives it the three ABI row
corrections **and** the world-token widening that lifts D1's extension-model exclusion. The second is
a *design* change. The first is a *repair* the compiler is currently demanding, and **it is what
stands between the tree and a green `check_core`.**

**Take part 1 only: settle the four `ExtensionHooks` rows, then close the cascade they imply.** The
world-token widening — and the two `ScriptedStep` widenings that ride with it — is part 2 and is
deliberately out of scope below.

## The rule you will break by accident

**You cannot repair the cascade without first deciding whether the ABI rows are final, because the
cascade's size is a function of the ABI — and repairing before deciding means repairing twice.**

Measured at HEAD:

| `ExtensionHooks` row | Effects today |
|---|---|
| `on_tool_handle` | nine **+ `Rand`** ← B1 widened this one |
| `on_pre_step` | nine |
| `on_response_intercept` | nine |
| `on_solver_candidate` | nine |

M2 predicted **all four** would gain `Rand` and `Trace`. B1 measured **one**, and correctly reported
that as *"one demanded so far"* rather than *"M2 over-predicted"* — the other three sat in modules
that never reached effect checking. **B3 removed that excuse.** Those modules now type-check far
enough to be asked, so the question is answerable for the first time, and answering it is this
item's first act.

**The stakes are the cascade's size, and it is large.** Rows are **closed**: widening an ABI hook
field does not permit narrower implementations, it *forces every one of them to widen in lockstep*.
That is why B1's single field cost 46 sites. Counted at HEAD, the four hook result types carry
**191 rowed implementation sites**:

```
ToolHandleDecision 49   PreStepDecision 59   ResponseInterceptDecision 40   FinalizeDecision 43
```

**So: measure whether the other three rows are demanded BEFORE repairing anything below them.** If
they are, repairing the cascade first means doing 191 sites' worth of work against a row that then
moves. If they are not, that is a finding worth as much as the repair — it would mean M2's prediction
was an artifact of the spike's own surgery.

## What the cascade actually is, and why it is not a pile of independent bugs

`compose.register_with_config` (`compose.ail:816`) is declared `! {Env, FS}` and constructs a hooks
record whose fields hold closures declaring nine and ten effects. **Constructing a record whose field
holds an effect-declaring closure makes the *constructing* function perform that effect** — so the
demand propagates **upward** through every `make_hooks` and `register_with_config` above a widened
hook.

Two things follow, both measured rather than assumed:

- **This is not a v0.33.0 regression.** B1 probed it: v0.26.0 does the same. It is already-filed
  `fb_74f53de3ae65854c`, and it is a *sizing fact*, not a new defect.
- **The missing effects are of two origins and both land on the same functions.** `Rand` comes from
  B1's ABI change (cascade). `AI, Clock, IO, Process` are **latent under-declarations that v0.26.0
  accepted and v0.33.0 rejects** (repair). You cannot separate them by editing; you can only separate
  them in the report, and doing so is what tells B4 which class it is re-verifying.

## Grounding, verified at HEAD

**B3's work is uncommitted — 46 files.** Confirm the tree is intact before starting; B3 inherited a
*committed* tree (`c013f69`) and my B3 handoff wrongly said otherwise, which is the state-claim
version of anchor decay.

The 74 remaining failures, from B3's sweep:

| Blocker | Files | Class |
|---|---|---|
| `motoko_ext_compose.register_with_config` — missing `AI, Clock, IO, Process, Rand` | **31** | effect row |
| `src/core/test/stub_step.live_ports` — missing `AI, Clock, Env, IO` | **21** | effect row |
| `dst_replay.ail:998` — `cannot unify record with unexpandable type constructor GeneratorBounds` | **7** | **type error — new species** |
| `compaction_ai.test_ai_drip_projected_relief_passthrough` — missing nine | **4** | effect row |
| `execution_program_dst.ail:87` — same `GeneratorBounds` | 1 | type error |
| `IMP010: 'MkHistory' not exported` | 1 | **the sealing probe — its failure IS its pass** |
| `LDR001: module not found: stub_step` | 1 | fixture |
| Pre-existing on v0.26.0 | **9** | baseline |

**This is a frontier, not a total.** `ailang check` stops at the first error per module, so four
distinct repairs are all that is visible behind 65 files. Expect the count to move as you clear it,
and **report the new frontier rather than treating a changed number as a discrepancy.**

**The `GeneratorBounds` failures are a new species and nothing in the plan anticipates them** —
neither effect row nor `images`. Diagnose before repairing; `GeneratorBounds` moved from `dst_program`
into `dst_generator` during A13 stage 4 and is re-exported, which is the first thing to check.

**`IMP010: 'MkHistory' not exported` is NOT a failure.** `scripts/probe_phase_vocab_sealed.ail` is a
sealing probe whose first line says it is *expected* to fail with `IMP010`; WI-A17 wired it with
inverted polarity. Six cluster reports called it broken before anyone read it. **Do not fix it.**

## Definition of done

**The four ABI rows settled by measurement**, with the answer stated either way — "three more
demanded" or "one only, and M2's other three were artifacts of the spike's surgery" are both results.

**Zero effect-row failures reachable**, which is B1's corrected gate re-satisfied at the new frontier.
Note B1's version of this claim was true when written and is now superseded; yours will be too, and
saying so is more useful than implying finality.

**`make check_core` green, or the fourth frontier named.** B3 expected green and got a moved wall;
the honest posture is to expect the same and report what is behind it.

**Per S10 — new, earned by B3 — drive tooling off the compiler's verdict, never its prose.**
`ailang check`'s `expected`/`actual` labels **flip by error context**, and its `Hint:` is derived from
whichever order was used, so a hint can be exactly backwards. B3's label-reading fix loop re-added a
field to three already-correct sites and oscillated thirty times on a fourth. **Flip-and-verify.**

**Per S9 — clear `.ailang/cache` before believing any check whose input you just mutated.** A cascade
repair across ~191 candidate sites is the highest-volume exposure this project has had.

**Every widening at the narrowest row that compiles.** B1's rule holds and its reason is sharper now
that `check_core` can nearly run: **D5's per-hook classification reads *declared* rows**, and the
three rowless slots (`on_describe_tools`, `on_build_system_prompt`, `on_tool_policy`) are the entire
coverable extension surface. B1 and B3 both left them byte-identical, verified by diff. **An
over-wide row here silently collapses D5's coverage**, and the check that would catch it —
`make profile_coverage` — passes today, so a regression is visible if you run it.

## Out of scope

- **WI-B2 part 2: the world-token widening** of `ExtPorts.ai_step`, the hook results and the core
  dispatch results — the change that lifts D1's extension-model exclusion — **and the two
  `ScriptedStep` widenings** (a provider *fault* needs an error case, a provider *latency* needs
  `advance_ms`; cluster 13 separated them and cluster 12's correction 2 conflated them). Those are
  design changes; this item is repairs and row decisions.
- **WI-B4's classifier re-derivation and manifest re-issue**, and the re-run of **both** unfinished
  mutation loops — B1's 20 cascade files and B3's 64 `images` sites, all **unverified, which must not
  read as verified**.
- **Removing the workarounds for the two AILANG defects v0.33.0 fixed.** Note the third,
  `fb_2ad074d754cd2c25`, is *still* untestable: its probe module now fails on `stub_step.live_ports`
  rather than on `images` — a new reason for the same blockage, and one **this item may clear.**
- **The stale `ailang 0.26.0` manifest strings** — 13 files, **stale not red**, and `driver_only_dst`
  passes because the string is data rather than a validated value. B4's, and an accuracy item.

## Stop and report rather than deciding inline

- **If the three remaining ABI rows are demanded**, that is an `motoko-ext-abi` **major** and a
  lockstep re-release of every extension package — say so before doing 191 sites, because the
  version decision is the plan's, not the session's.
- **If `GeneratorBounds` needs a change to `dst_generator`'s exports**, note that stage 4 moved it
  deliberately and stage 5's canary pins that module's stream; a re-pin may follow.
- **If a repair requires widening a rowless ABI slot**, stop. That is D5's coverable surface and
  losing it is a conformance regression, not a compile fix.

## Traps

**Read `make dst`'s exit status, never its output**; **do not run other `make` targets concurrently.**
`make dst` currently exits 2 on the compose row and never reaches a manifest check.

**A5 anchors: `stub_step.ail:161`; `session.ail`'s 948 / 1053 / 2290 / 2400; `driver_only` is v3.**
`stub_step.live_ports` is in the 21-file blocker, so **this item edits an anchored file** — write
below the anchor, widen lines in place, and run `sed -n '161p'` after each edit. Six items have paid
zero this way; the cascade correlates with adding a `StepProvider` **variant**, which this item
should not need.

**`AILANG_RELAX_MODULES=1` to sweep `packages/`**; **the stdlib is global**, so use
`AILANG_STDLIB_PATH` if you compare against another compiler; **never probe from `/tmp`**.

## Report back

Eighteenth calibration run.

- **The git wall-clock window.**
- **The ABI answer** — one row or four — and how it was measured. This is the headline.
- **Sites and files**, split by origin: cascade (from a widened ABI row) versus latent
  under-declaration (v0.26.0 accepted, v0.33.0 rejects). B4 needs that split.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** **37 across seventeen runs; determinism has caught none.** B3 measured *zero*
  silent-wrong sites among 72 forced ones and explained why — closed records make a wrong-direction
  literal a type error at first typed contact. **A row widening has no such protection**: a
  too-wide row compiles, so this item's exposure is the opposite of B3's.
