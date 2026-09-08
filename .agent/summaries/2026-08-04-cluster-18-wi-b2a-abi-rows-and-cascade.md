# 2026-08-04 Cluster 18: WI-B2a — the ABI rows, and the cascade beneath them

## Context

Branch: `arniwesth/mot-57-execute-wi-b2-part-1`.

Session span: `7bca61c` → **uncommitted working tree, 79 `.ail` files + `ailang.lock`**. Input was
`HANDOFF-execute-b2a-abi-rows-and-cascade.md`, executed cold against HEAD. Eighteenth code session of
project 009, third of Milestone B. Pin **v0.33.0**.

**Window: 2h13m**, `16:26:52Z` → `18:40:03Z`. The large majority is machine time — fifteen
compiler-driven fixer rounds, four whole-tree sweeps, two row-mutation runs, `check_core` five times,
`make dst`, `sync_packages` three times. **Roughly forty minutes was one false red** that five wrong
hypotheses could not explain (see S9 below).

| Definition-of-done item | State |
|---|---|
| The four `ExtensionHooks` rows settled by measurement | **met** — and the answer includes a fifth row nobody asked about |
| Zero effect-row failures reachable | **met** |
| `make check_core` exit 0 | **met** — 51/51, 7 extensions booted. First green since the repin |
| `make dst` — say what it does | **exit 2**, and it now gets 3.4× further than B3 left it |

**Tree: 218 pass / 17 fail**, from 161 / 74 at session start. B1's matched v0.26.0 baseline was
213 / 22, so the tree now type-checks *more* files than before the repin — the first point in
Milestone B where that is true.

## Grounding correction, and it is the third consecutive one

The handoff says B3's work is "uncommitted — 46 files", and *explicitly warns* that B3 inherited a
committed tree while its own handoff claimed otherwise. It then makes the same error: B3's work **was**
committed, as `7bca61c` ("Implemented"), and the tree was clean at start.

B1's handoff got this wrong about B1. B3's got it wrong about B3. This one got it wrong about B3
again — in a paragraph explicitly about not getting it wrong. **The file contents matched the
description exactly every time.** The claim to stop making is the commit state; nobody has yet been
wrong about the file count.

## The headline: two ABI rows demanded, and only one is a hook

The handoff framed the question as "are the other three `ExtensionHooks` rows demanded?", with 191
sites riding on the answer, and its central rule was about **order**: settle the rows before
repairing beneath them, or repair twice.

| Row | Verdict |
|---|---|
| `ExtPorts.ai_step` | **+`Trace`** — M2 predicted it; B1 could not confirm it (module died on `images` first) |
| `ExtensionHooks.on_pre_step` | **+`Trace`**, as a *consequence* of the above |
| `ExtensionHooks.on_tool_handle` | unchanged — B1's `+Rand` was already correct |
| `ExtensionHooks.on_response_intercept` | **NOT demanded** |
| `ExtensionHooks.on_solver_candidate` | **NOT demanded** |

**How the order was kept.** The 191 rowed sites were untouched until the answer was in. The
instrument was a fixer driven off the compiler's *verdict* (S10) carrying a hard refusal: any demand
landing on a function whose return type is one of the four decision types is **reported, never
absorbed**. The tree was repaired to fixpoint *around* the rows with that guard armed through fifteen
rounds. It fired twice.

- **First signal, and it was not a hook.** A **lambda** — `session.ext_ports_of`'s `ai_step` bridge at
  `session.ail:772` — failed against its own nine-effect annotation, needing `Trace`.
  `Ports.model_step` has carried `Trace` since WI-A1; `ext_ports_of` bridges `Ports` to `ExtPorts`; a
  closed row cannot hide the crossing.
- **Second signal, the consequence of the first**, and the only one touching a hook:
  `compaction_ai.fresh_compaction -> PreStepDecision demands ['Trace']`.

**Why the other two rows are safe is checkable rather than plausible:** `Trace` reaches the extension
surface *only* through `ExtPorts.ai_step`, and the tree has exactly two extension-code callers of
`ai_step` — `compaction_ai.summarize_attempt:106` and `reject_fixtures.nocache_pre_step:90`. Both are
on the `on_pre_step` path. So the cascade cost **62 sites, not 191**, and the handoff's stop trigger
("if the three remaining rows are demanded … before doing 191 sites") held on neither clause.

**M2 was right about `ai_step += Trace` and right that hook rows would gain `Trace`; it was wrong
about the breadth.** It predicted all four hooks gain both `Rand` and `Trace`. Measured: one hook
gains `Trace`, one gained `Rand` (B1), two gain nothing.

### Both widenings mutation-tested, and the detector nearly lied

A too-wide row **compiles** — widen the row and every implementation in lockstep and nothing
complains — so B3's protection (closed records make a wrong literal a type error at first contact)
does not apply. The detector must remove the effect from the row **and** all implementations together.

| Mutation | Sites | Verdict |
|---|---|---|
| all `ai_step` rows `− Trace` | 10 | **RED** at `session.ext_ai_step` — load-bearing |
| all `PreStepDecision` rows `− Trace` | 59 | **RED** at `compaction_ai.fresh_compaction` — load-bearing |

**The first mutation reproduced B1's per-file blind spot, and that is the more useful half.** Probed
from `compaction_ai.ail`, the same mutation reads **GREEN**, because that module over-declares `Trace`
independently. Probed from `session.ail`, where the demand arises, it is RED. **A row mutation is only
observable from the module that forces it**, and a probe chosen by convenience turns a load-bearing
row into a false "over-wide" finding.

## S9 is wrong as written — the run's most transferable finding

**The repo contains 34 `.ailang/cache` directories. `rm -rf .ailang/cache` clears one of them.**

Every session following S9 — B1, B3, and this one for its first three hours — cleared the **root**
cache and left **33 warm**, one per source directory (`src/core/`, `src/core/ext/`, `scripts/dst/`,
each `packages/*/`, …).

It produced a false red that survived: a repo-local cache clear, a full `sync_packages`, a
`rm -rf .packages` and rebuild, an `ailang lock` refresh, and two wrong source-level hypotheses (a
package `[effects] max` ceiling, and the record-update construct of `fb_e44ba922db1c42be`). The
error — `compaction_ai.ail:571`, `ai_step` row mismatch — was a stale per-directory cache holding a
pre-`Trace` interface. Clearing all 34 fixed it with **no source change**.

Three consequences:

1. This run's first post-repair sweep (217/18) was cache-contaminated; `sweep.sh` is fixed.
2. So was every sweep this project has recorded — B1's 130/105, B3's 161/74, B1's v0.26.0 baseline
   213/22. Not necessarily *wrong*, but none is the cache-cold measurement it claims.
3. **The 33 caches are TRACKED IN GIT.** They travel between branches and sessions, so a stale
   interface can arrive by checkout with no local edit to explain it. There is no
   `ailang cache clean` for compile caches (`ailang cache` is the semantic-brain feature).

**Proposed S9 replacement:** *"Clear **every** `.ailang/cache` in the repo —
`find . -type d -name cache -path '*.ailang*' -exec rm -rf {} +` — before believing any check whose
input you just mutated. There are 34, not one, and they are tracked in git."*

## A second species the plan did not anticipate: `export type X = X`

The handoff flagged `GeneratorBounds` as a new species to diagnose before repairing. Diagnosed:
`dst_program.ail:97` carried `export type GeneratorBounds = GeneratorBounds`, a re-export idiom
v0.33.0 resolves to *itself*. The alias is accepted at its declaration and unexpandable thereafter, so
it fails at **every construction site and never at the cause**.

**The tree carried two instances, and I got the second wrong in a comment before the compiler
corrected me.** I wrote that `stub_step.ail:49`'s `export type ScriptedStep = ScriptedStep` was
*latent*, safe because `ScriptedStep` was an ADT matched by constructor. **It is a record, and it was
blocking 33 files** — invisibly, because they all died on an effect row first. The comment now states
the real rule: the form is a defect wherever `X` is a record, green tree or not.

Repair: both re-exports removed; `GeneratorBounds`'s 2 importers repointed to `dst_generator`,
`ScriptedStep`'s **22** importers repointed to `ports`. **No change to `dst_generator`'s exports**, so
stage 4's move stands and stage 5's canary needs no re-pin.

## A5's attribution anchors were ALREADY STALE at HEAD — nine of ten

`make dst` reaches `attribution_table` for the first time since the repin and it goes red. **Nine of
its ten anchors do not match at HEAD, before any edit of mine** — only `ext/runtime.ail:190` matches.
`stub_step.ail:161` wants `now()` and has `let clock_now: … =`; `session.ail` 948/1053/2290/2400 want
`clock_now` and have `else {` and three comments.

**The handoff's framing — "six items have paid zero this way" — describes a discipline that had
already failed.** The table drifted earlier and nothing reported it, because `make dst` exited 2 long
before reaching the check. Absent read identically to unchanged, one level up from where B1 and B3
found it.

**I introduced no new drift**; all ten anchor lines were compared against HEAD after every edit.
Re-deriving the table is a D4 judgement and belongs with B4 — it is now *visible*, which it was not.

### The guard that earned its keep

The repair tool asserts on **every** edit that the file's **line count is unchanged**, because A5's
anchors are line numbers. **It fired on `session.ail`**, refusing a rewrite of
`test_runtime_status_includes_prior_conversation_counts` that would have gone 2962 → 2961 lines and
silently moved anchors 2290 and 2400. The bug was an `rstrip()` eating the newline before the body
brace. Six items have paid zero here by remembering; this is the first to make it mechanical, and it
caught a real instance within an hour of being written.

## Sites and files, split by origin — what B4 asked for

**79 `.ail` files; 448 insertions / 402 deletions.** Two populations, distinguished by how the
compiler reports them.

**A. Closed-row lockstep — pure cascade, 123 sites.** Found by grep, fixed in bulk, because a closed
row admits exactly one width: `PreStepDecision +Trace` 62 (59 typed + 3 lambda-form),
`ExtPorts.ai_step +Trace` 10, `ToolHandleDecision +Rand` 3 (**B1's**, behind the `images` wall),
`dst_harness.Scenario.run +Rand` 48.

**B. Compiler-demanded function rows — 180 distinct sites across 42 files**, each reported
individually as `Missing effects:` over fifteen rounds:

| Demanded | Sites | Origin |
|---|---|---|
| `Rand` alone | **113** | **cascade** — entered via B1's `on_tool_handle` row, propagated upward |
| `Trace` alone | **36** | **cascade** — entered via this item's `ai_step` row |
| a multi-effect set | **31** | **latent under-declaration** — v0.26.0 accepted, v0.33.0 rejects; `fb_74f53de3ae65854c`'s upward propagation |

**So the honest split is 262 cascade against 31 latent** — the repin's genuinely *new* demand is
small, and the overwhelming majority of the diff is one ABI row's blast radius arriving twice.

**C. Type and seam repairs:** 2 `export type X = X` removed with 24 importers repointed; 8 `images`
sites (B3's class, newly reachable) — 5 over-applied and removed, plus 2 new converters. **On
`rpc.ail:239` the compiler's `Hint` said "add the field(s) to the literal" and the fix was to delete
it** — S10 confirmed in the wild, on a site S10 did not come from. The two new converters run in
*opposite* directions and each one's comment names the other, which is B3's trap reproduced inside a
single item.

## Silent-wrong-answer sites: 0 measurable, and the reason is structural

**Running total stays at 37 across eighteen runs. Determinism has still caught none.**

Every one of the 123 closed-row sites is compiler-forced, and unlike B3 this needs no per-site
mutation loop to establish: **closed rows admit exactly one answer** — an implementation row must
*equal* its ABI field's row, so no band exists in which two widths type-check. The only silent-wrong
mode available is the *row itself* being too wide, and both changed rows were mutation-tested above.

**Unmeasured, and it must not read as verified: the 180 function rows of population B.** Each is
`-> T ! {row}` on an ordinary function, where a wider row type-checks fine — the silent band B1's
three defects lived in. The tool adds exactly the compiler's demanded set, minimal *as reported*, but
that is not minimal *in fact*: the compiler reports what a body needs **given its callees' declared
rows**, so one over-wide callee propagates a too-wide answer upward and every caller type-checks.
**B4's mutation loop should target these 180, not the 123** — and B1's three known over-widenings
(`context_mode.ail:163`, `omnigraph.ail:79` and `:113`) are exactly this shape.

**What caught this run's defects:** the line-count guard (1 anchor-moving rewrite), the parse-check
revert (1 corrupted file), the ABI guard (2 signals, both real), the all-34 cache clear (1 false red),
and the whole-tree sweep (4 missed cascade sites). **What did not:** the compiler's `Hint`, backwards
again; and `rm -rf .ailang/cache`, the instrument everyone trusted.

### A defect I shipped, and it is B3's lesson unlearned

B3's tooling-first rider says prove the rewriter lossless *before* touching the tree. I did not. My
first fixer inserted a row **after** a `tests [...]` clause, producing a parse error that propagated
as "parse errors in compaction_ai" into ~20 downstream targets' logs before I read it. The fix was
structural rather than a better regex: **the tool now re-checks after every edit and reverts any edit
that does not parse**, and asserts locality and line count. That guards every edit rather than a
sample, which is stronger than the round-trip harness I had started building.

### And the sweep caught what fifteen fixer rounds could not

The first honest sweep reported 214/21 and surfaced **four failures invisible to the round-based
loop**: `tools/ext_call_inventory/fixtures/{control_resolved, form_alias, form_computed,
form_reexport}` — A4's classifier-2 form fixtures, each calling `ai_step` and so needing `Trace`. They
were never in the loop's target list because they *passed* at s0. **A repair loop seeded from the
failing set cannot see what its own change breaks; only a whole-tree sweep can.** With them fixed,
`ext_call_inventory_selftest` exits 0 with its **pinned membership block unchanged**, confirming
rather than assuming that this ABI major does not move classifier-2's answer.

## Other gates

`make CI=1 sync_packages` exit 0 (B1's drift gate intact). `make profile_coverage` exit 0, still
asserting three distinguishable rowless hook ids — **D5's coverable surface intact**, verified by diff
as well: `on_describe_tools`, `on_build_system_prompt`, `on_tool_policy` byte-identical to HEAD.

**`make dst` exits 2**, read as status not prose. Log is **3895 lines against B3's 1153**, 26 suite
PASS markers. Three targets fail, all previously unreachable, none an effect row: `attribution_table`
(the nine stale anchors), `test_coverage` (`prompts_test.ail` 0/6, deterministic
`LDR001: module not found: src/core/prompts` across three runs — **not** the intermittent
`fb_2ad074d754cd2c25`), and `test_coverage_selftest`.

**`fb_2ad074d754cd2c25` is now testable and was not tested** — its probe module `dst_invariants.ail`
was blocked on `stub_step.live_ports`, which this item cleared, exactly as the handoff predicted. A
deliberate omission: it is B4's ticket work and wants a clean 10-run measurement.

## Deliberately not done

- **7 `TC_ARITY_001` smoke scripts** calling `run_v2` with 10 of 13 args. Call sites **byte-identical
  at HEAD**; `run_v2`'s arity unchanged. The sibling `_full_loop` scripts all pass and call
  `run_v2_with_scripted_ports` instead, and **all seven** stale callers are stale the same way — there
  is no correct in-tree caller to copy. Repair means choosing a `StepProvider` for **live API calls**;
  deletion or migration is likelier right, and both are someone's deliberate call.
- **A5's attribution table** (argued above).
- **Every package version and `[effects] max` ceiling.** No package declares `Trace` or `Rand`; this
  blocked nothing here, and the ceiling was confirmed *not* to be the cause of the `compaction_ai`
  error. But **the ABI now carries two changed rows across B1 and B2a and the lockstep re-release is
  owed** — stated rather than taken, because the version decision is the plan's.
- **WI-B2b** (world-token widening, the two `ScriptedStep` widenings) and **WI-B4** (classifiers,
  manifest re-issue, the 13 stale `ailang 0.26.0` strings, the mutation loops). The two v0.33.0-fixed
  defect workarounds, untouched.

## Corrections owed to the plan

1. **S9 is wrong as written.** Replacement above. Highest-value correction in the report.
2. **The 191-site figure is 206.** The plan counts only `<Type> ! {row}` annotations; there are a
   further **15 lambda-form** hook assignments the grep misses and the closed-row lockstep binds
   identically. Per type: `ToolHandleDecision` 52, `PreStepDecision` 62, `ResponseInterceptDecision`
   45, `FinalizeDecision` 47. Three of the 15 were B1's un-widened cascade sites, which is how the
   undercount surfaced.
3. **WI-B2's row corrections are landed and should be struck from B2b**, leaving B2b the world-token
   widening alone.
4. **`export type X = X` should be a named prohibition**, not a discovered one.
5. **A5's anchor discipline needs a mechanical check, not a rule** — and the anchors themselves need
   re-deriving before the next item trusts them.

## A process note worth recording

Mid-session I ran `git stash push -- <one file>` on a file that turned out to be unmodified. It saved
nothing and returned 0, so the following `git stash pop` popped a **pre-existing stash from another
branch**. It was empty (its diff against its parent was zero files), and I restored it with
`git stash store`. No contamination, but the lesson is cheap: **`git stash push` on an unmodified path
is a silent no-op, so a paired `pop` targets somebody else's stash.**

## Artifacts

- `.agent/projects/009_motoko_dst_execution/NOTE-b2a-execution-report-and-plan-corrections.md` — the
  execution report.
- Scratchpad instruments: `effectfix.py` (verdict-driven row repair — module→file resolution, refuses
  the ABI file and `.packages/`, **reports rather than absorbs** any demand on a decision type,
  reverts any edit that does not parse, asserts locality and line count), `mut2.py` (surgical
  marker-scoped row over-widening detector), `sweep.sh` (whole-tree sweep, now genuinely cache-cold).
  The line-count guard and the all-34 clear are the two worth keeping; B4 needs both.

**Nothing is committed.** 79 source files, `ailang.lock`, the note and this summary are working-tree
changes on `arniwesth/mot-57-execute-wi-b2-part-1`. Stated plainly because three handoffs in a row
have got this wrong in the other direction.
