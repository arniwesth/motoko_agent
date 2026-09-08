# WI-B2a execution report — the ABI rows, and the cascade beneath them

Eighteenth calibration run, third of Milestone B. Written against HEAD `7bca61c`, branch
`arniwesth/mot-57-execute-wi-b2-part-1`.

## Window

**2h13m** wall-clock: `2026-08-04T16:26:52Z` → `2026-08-04T18:40:03Z`. The large majority is machine
time — fifteen compiler-driven fixer rounds, four whole-tree sweeps, two row-mutation runs,
`check_core` four times, `make dst`, and `sync_packages` three times, most of it cache-cold. **Roughly
forty minutes of it was spent chasing a false red that five wrong hypotheses could not explain and
the 34-cache clear fixed in one command** — see S9 below.

**A grounding correction first, and it is the third in a row.** The handoff says B3's work is
"uncommitted — 46 files", and warns that B3 inherited a committed tree while its own handoff said
otherwise. It then makes the same error: B3's work **was** committed, as `7bca61c` ("Implemented"),
and the tree was clean at start. B1's handoff got this wrong about B1, B3's got it wrong about B3,
and this one got it wrong about B3 again — **in a paragraph explicitly about not getting it wrong.**
The file *contents* matched the description exactly every time. **The claim to stop making is the
commit state; nobody has yet been wrong about the file count.**

## The headline: the ABI answer is TWO rows, and only one of them is a hook

The handoff framed the question as "are the other three `ExtensionHooks` rows demanded?" — with 191
sites riding on the answer. **Measured, the answer is no for two of the three, yes for one, and there
is a fifth row nobody was asking about that turned out to be the cause of all of it.**

| Row | Before | After | Verdict |
|---|---|---|---|
| `ExtPorts.ai_step` | nine | nine **+ `Trace`** | **DEMANDED** — M2 predicted it; B1 could not confirm it |
| `ExtensionHooks.on_pre_step` | nine | nine **+ `Trace`** | **DEMANDED**, as a *consequence* of the above |
| `ExtensionHooks.on_tool_handle` | nine + `Rand` | unchanged | B1's, already correct |
| `ExtensionHooks.on_response_intercept` | nine | **unchanged** | **NOT demanded** |
| `ExtensionHooks.on_solver_candidate` | nine | **unchanged** | **NOT demanded** |

**How it was measured, and the order matters because the handoff's central rule is about order.** The
191 rowed sites were not touched until the answer was in. The instrument was a fixer driven off the
compiler's *verdict* (S10) with a hard refusal: any demand landing on a function whose return type is
one of the four decision types is **reported, never absorbed**. The tree was then repaired to
fixpoint *around* the rows, and the guard was left armed through fifteen rounds. It fired twice.

**The first signal was not a hook at all.** A **lambda** — `session.ext_ports_of`'s `ai_step` bridge
at `session.ail:772` — failed against its own nine-effect annotation, needing `Trace`. That is
`ExtPorts.ai_step`, M2's fifth prediction, which B1 reported as unmeasured because the module died on
`images` first. `Ports.model_step` has carried `Trace` since WI-A1; `ext_ports_of` bridges `Ports` to
`ExtPorts`; a closed row cannot hide the crossing.

**The second signal was the consequence of the first**, and it is the only one that touched a hook:
`compaction_ai.fresh_compaction -> PreStepDecision demands ['Trace']`, because `ai_step` now carries
`Trace` and `summarize_with_ai` calls it.

**Why the other two rows are safe is a one-line argument that is checkable rather than plausible:**
`Trace` reaches the extension surface *only* through `ExtPorts.ai_step`, and the tree has exactly
**two** extension-code callers of `ai_step` — `compaction_ai.summarize_attempt:106` and
`reject_fixtures.nocache_pre_step:90`. **Both are on the `on_pre_step` path.** No
`on_response_intercept` or `on_solver_candidate` implementation reaches it. So the cascade cost
**62 sites, not 191** — and that is why this item did not stop to ask: the handoff's stop trigger is
*"if the three remaining ABI rows are demanded … before doing 191 sites"*, and neither clause holds.

**Two riders on that count, both checked rather than assumed.** First, a further five `ai_step` call
sites exist in `tools/ext_call_inventory/fixtures/` (`form_alias`, `form_computed`, `form_wrapper`,
`form_reexport`, `control_resolved`) — they are **A4's classifier-2 form fixtures**, they register no
hooks, and they are outside the ABI. They do mean **B4 should re-run `ext_call_inventory_selftest`**:
its pinned membership block is exactly what goes red if the ABI major changes the answer, and the
answer here is that `ai_step` remains classifier-2, so it should *not* move. Second, `dst_driver_only`
and `dst_fault_catalogue` both carry prose saying "widening `ExtPorts.ai_step` is Milestone B's ABI
major, not a fix available here", justifying D1's extension-model exclusion. **That prose is still
correct and was deliberately left alone**: the exclusion is lifted by the **world-token** widening
(B2b), not by this effect-row correction, so nothing about D1's omission of `compaction_ai` changes.

**M2 was right about `ExtPorts.ai_step += Trace` and right that hook rows would gain `Trace`. It was
wrong about the breadth** — it predicted all four hooks would gain both `Rand` and `Trace`; the
measured answer is one hook gains `Trace`, one gained `Rand` (B1), and two gain nothing.

### Both widenings are load-bearing, and this item's exposure was the inverse of B3's

The handoff is right that **a too-wide row compiles** — widen the row and every implementation in
lockstep and nothing complains — so B3's protection (closed records make a wrong literal a type error
at first contact) does not apply here. The detector has to remove the effect from the row **and** all
implementations together and ask whether anything goes red. Both mutations, genuinely cache-cold:

| Mutation | Sites | Verdict |
|---|---|---|
| all `ai_step` rows `− Trace` | 10 | **RED** at `session.ext_ai_step` — load-bearing |
| all `PreStepDecision` rows `− Trace` | 59 | **RED** at `compaction_ai.fresh_compaction` — load-bearing |

**The first mutation ALSO reproduced B1's per-file blind spot, and this is the more useful half.**
Probed from `compaction_ai.ail` the same mutation reads **GREEN** — because that module over-declares
`Trace` independently, so the row's removal is invisible there. Probed from `session.ail`, where the
demand actually arises, it is RED. **A row mutation is only observable from the module that forces
it**, and picking the wrong probe turns a load-bearing row into a false "over-wide" finding. B1 named
this blind spot; it is not merely live, it is the default outcome if the probe is chosen by
convenience.

## S9 is wrong as written, and this is the run's most transferable finding

**The repo contains 34 `.ailang/cache` directories. `rm -rf .ailang/cache` clears one of them.**

S9 says "clear the compile cache before believing any check whose input you just mutated". Every
session that has followed it — B1, B3, and this one for its first three hours — ran
`rm -rf .ailang/cache`, which clears the **root** cache and leaves **33 warm**, one per source
directory (`src/core/`, `src/core/ext/`, `scripts/dst/`, each `packages/*/`, …).

**It cost hours here and it produced a false green.** After the row mutations, `make check_core`
dropped from 51/51 to 44/51 and stayed there through: a repo-local cache clear, a full
`sync_packages`, a `rm -rf .packages` and rebuild, an `ailang lock` refresh, and two source-level
hypotheses that were both wrong (a package `[effects] max` ceiling, and the record-update construct
of `fb_e44ba922db1c42be`). The error — `compaction_ai.ail:571`, `ai_step` row mismatch — was a stale
per-directory cache holding a pre-`Trace` interface. Clearing all 34 fixed it with **no source
change**.

Three consequences, and the third is the one that should worry B4:

1. **The earlier whole-tree sweep in this run (217 pass / 18 fail) was cache-contaminated.** It
   cleared the root cache once and then checked 235 files against 33 warm ones. The honest number is
   below; the instrument is fixed in `sweep.sh`.
2. **The same is true of every sweep this project has recorded**, including B1's 130/105, B3's
   161/74, and B1's v0.26.0 baseline of 213/22. They are not necessarily *wrong* — a warm cache is
   only harmful when its input changed — but none of them is the cache-cold measurement it claims.
3. **The 33 caches are TRACKED IN GIT.** They are `.gob` files under `.packages/*/.ailang/cache/` and
   under each source directory, they appear in `git status` on every run, and **they travel between
   branches and between sessions.** A stale interface can therefore arrive by checkout, with no local
   edit to explain it. That is a phantom no per-session discipline can catch.

**Proposed S9 replacement:** *"Clear **every** `.ailang/cache` in the repo — `find . -type d -name
cache -path '*.ailang*' -exec rm -rf {} +` — before believing any check whose input you just mutated.
There are 34, not one, and they are tracked in git, so they also arrive by checkout."*

## A second defect species the plan did not anticipate: `export type X = X`

The handoff flagged `GeneratorBounds` as a "new species — diagnose before repairing". Diagnosed:
**`src/core/dst_program.ail:97` carried `export type GeneratorBounds = GeneratorBounds`**, a
re-export idiom that v0.33.0 resolves to *itself*. The alias is accepted at its declaration and is
unexpandable thereafter, so it fails at **every construction site and never at the cause**.

**The tree carried two instances, and I got the second one wrong in a comment before the compiler
corrected me.** I wrote that `stub_step.ail:49`'s `export type ScriptedStep = ScriptedStep` was a
*latent* instance, safe because `ScriptedStep` was an ADT matched by constructor. **It is a record,
and it was blocking 33 files** — invisibly, because they all died on an effect row first. The comment
in `dst_program.ail` now says so, and states the real rule: the form is a defect wherever `X` is a
record, whether or not the tree is currently green.

Repair: both re-exports removed; `GeneratorBounds`'s two importers repointed to `dst_generator`,
`ScriptedStep`'s **22** importers repointed to `ports`. **No change to `dst_generator`'s exports**, so
stage 4's deliberate move stands and stage 5's canary needs no re-pin — the handoff's stop-and-report
condition for this did not fire.

## A5's attribution anchors were ALREADY STALE at HEAD — nine of ten

This is the finding I expected to be about my own discipline and is not.

`make dst` reaches `attribution_table` for the first time since the repin and it goes red. **Nine of
its ten anchors do not match at `HEAD`, before any edit of mine:**

| Anchor | Expects | Actual at HEAD |
|---|---|---|
| `ext/runtime.ail:190` | `now()` | ✅ the only one that matches |
| `tool_phase.ail:286` | `is_scratchpad_tool_name` | a return-type annotation |
| `tool_phase.ail:287` | `exec_scratchpad_cell_ws` | `let envelope = …` |
| `session.ail:807` | `now()` | a comment |
| `stub_step.ail:161` | `now()` | `let clock_now: … =` |
| `session.ail` 948 / 1053 / 2290 / 2400 | `clock_now` | `else {` and three comments |
| `tool_phase.ail:342` | `clock_now` | a comment |

**The handoff's framing — "six items have paid zero this way" — describes a discipline that had
already failed.** The table drifted at some earlier point and nothing reported it, because `make dst`
exited 2 long before reaching the check. Absent read identically to unchanged, one level up from
where B1 and B3 found it.

**I introduced no new drift.** All ten anchor lines were compared against `HEAD` after every edit;
nine are byte-identical and the tenth (`tool_phase.ail:286`) changed only by gaining `Rand` in its
row — and it did not match its anchor at HEAD either. The line-count guard below is what kept it
that way.

**Re-deriving the table is not this item's** — choosing which site is "the" attributed site is a D4
judgement, and the table has other consumers. It belongs with B4's accuracy pass, and it is now
*visible*, which it was not before.

### The guard that earned its keep

The repair tool asserts, on **every** edit, that the file's **line count is unchanged** — because A5's
anchors are line numbers and a widening that collapses a multi-line signature moves every anchor
below it. **It fired on `session.ail`**, refusing a rewrite of
`test_runtime_status_includes_prior_conversation_counts` that would have gone 2962 → 2961 lines and
silently moved anchors 2290 and 2400. The bug was an `rstrip()` eating the newline before the body
brace. **Six items have paid zero here by remembering; this is the first to make it mechanical**, and
it caught a real instance within an hour of being written.

## Sites and files, split by origin — B4's split

**79 `.ail` files changed; 448 insertions / 402 deletions** (plus `ailang.lock`, regenerated by
`sync_packages` for the packages edited — B3's situation repeating). Two populations, and they divide
cleanly because the compiler reports them by different mechanisms.

**A. Closed-row lockstep sites — pure cascade, forced by a widened ABI/shared row.** Found by grep and
fixed in bulk, because a closed row admits exactly one width. Counts verified against the tree:

| Row | Sites now carrying the effect | Of which the declaration |
|---|---|---|
| `PreStepDecision` `+Trace` | **62** (59 typed + 3 lambda-form) | 1 (the ABI) |
| `ExtPorts.ai_step` `+Trace` | **10** | 1 (the ABI) |
| `ToolHandleDecision` `+Rand` | **3** lambda-form | 0 — these are **B1's**, in files that were behind the `images` wall |
| `dst_harness.Scenario.run` `+Rand` | **48** scenario rows | 1 |

**B. Compiler-demanded function rows — 180 distinct sites across 42 files**, each reported
individually as `Missing effects:` and fixed one at a time over fifteen rounds. This population splits
by *what* was demanded, and that split is the cascade/latent boundary B4 needs:

| Demanded | Sites | Origin |
|---|---|---|
| `Rand` alone | **113** | **cascade** — `Rand` entered the tree through B1's `on_tool_handle` row and propagated upward through every caller |
| `Trace` alone | **36** | **cascade** — `Trace` entered through *this item's* `ai_step` row and propagated the same way |
| a multi-effect set | **31** | **latent under-declaration** — v0.26.0 accepted these, v0.33.0 rejects them; they are `fb_74f53de3ae65854c`'s upward propagation of closure rows, and they were always wrong |

**So the honest split is 262 cascade sites against 31 latent ones** — the repin's genuinely *new*
demand is small, and the overwhelming majority of this diff is one ABI row's blast radius arriving
twice. That is the number B1 could not compute (its 66/46 was the frontier, not the total) and the
one that should size B2b.

**C. Type and seam repairs**, small and individually argued: 2 `export type X = X` declarations
removed with 24 importers repointed, and 2 new converters plus 8 literal corrections in B3's
`images` class.

### B3's `images` class was not finished, because it could not be

**Eight `images` sites were behind the third frontier and are repaired here** — four over-applied
(removed) and four under-applied or seam-crossing (added, via two new converters). They are B3's
64 unverified sites arriving, and they land in both directions exactly as B3 predicted:

- `rpc.ail:239` and `_smoke.ail:63` and `phase_c_l1_scenarios.ail` ×3 — **over-applied**, `images`
  removed. On `rpc.ail` **the compiler's `Hint` said "add the field(s) to the literal" and the fix was
  to delete it** — S10 confirmed in the wild, on a site S10 did not come from.
- `long_qwen_compaction_dst.msgs_to_messages` — **new converter, ADDING direction** (`[Msg]` →
  `[Message]` for the `ai_step` bridge).
- `phase_c_l1_scenarios.messages_to_msgs` — **new converter, DROPPING direction** (`[Message]` →
  `[Msg]` for `validate_compactor_output`).

**Those two converters are B3's trap reproduced in one item**: opposite directions, structurally
identical, and each one's comment names the other so the next reader cannot uniformly apply either.

## Recorded bindings: decided versus discovered

**Discovered — the compiler forced them and I only transcribed:** all 62 `PreStepDecision` rows, all
10 `ai_step` rows, the 3 `ToolHandleDecision` rows, and the ~113 function rows. Every one is the
narrowest row that compiles, because the tool adds exactly the compiler's `Missing effects` set and
nothing else.

**Decided — a human chose, and each is a place a future reader should look:**

1. **`ExtPorts.ai_step += Trace` rather than un-routing `Trace` at the bridge.** The alternative was
   to stop `ext_ports_of` from performing `Trace`, which would mean an extension's AI calls vanish
   from the trace. Rejected: D1's whole point is that the extension seam is observable.
2. **Removing both `export type X = X` re-exports rather than restating the record.** Restating would
   duplicate a type that must not diverge. There is no re-export idiom in AILANG's docs (searched).
3. **`ScriptedStep` importers repointed to `ports` rather than adding a shim.** 22 files, 9 of them
   in-place with no line shift.
4. **The two new `Msg`/`Message` converters' directions**, per B3's settled decision.
5. **Dropping `pure` from two `session.ail` test functions** that became effectful because
   `scripted_ports()` gained `{IO, Trace}`. Not a free choice — the compiler demands the row and
   `pure` forbids it — but worth recording that an AILANG defect's blast radius now reaches `pure`
   annotations.
6. **NOT re-deriving A5's attribution table**, NOT fixing the 7 stale smoke-script callers, and NOT
   bumping any package version. All three are argued below.

## Sites where two answers type-checked and one was silently wrong: 0 measurable, and the reason is structural

**Running total stays at 37 across eighteen runs. Determinism has still caught none.**

Every one of the **123 closed-row lockstep sites** (population A) is **compiler-forced**, and unlike
B3 I can say why without a mutation loop over each: **closed rows admit exactly one answer.** An
implementation row must *equal* its ABI field's row — not a subset, not a superset — so there is no
band in which two widths both type-check. The only silent-wrong mode available there is the *row
itself* being too wide, and both rows this item changed were mutation-tested above and are
load-bearing.

**What that leaves unmeasured, and it must not read as verified: the 180 function rows of population
B.** Each is `-> T ! {row}` on an ordinary function, where a **wider** row type-checks fine — the
silent band B1's three defects lived in. The tool adds exactly the compiler's `Missing effects` set,
which is minimal *as reported*, but that is not minimal *in fact*: the compiler reports what a body
needs **given its callees' declared rows**, so one over-wide callee propagates a too-wide answer to
every caller above it, and every one of them type-checks. **B4's mutation loop should target these
180, not the 123** — and B1's three known over-widenings (`context_mode.ail:163`, `omnigraph.ail:79`
and `:113`) are of exactly this shape, so the population is known to contain the defect.

**What caught this run's actual defects:** the line-count guard (1 anchor-moving rewrite, pre-commit);
the parse-check revert (1 corrupted file); the ABI guard (2 signals, both real); and the all-34 cache
clear (1 false red that had survived five other explanations). **What did not:** the compiler's
`Hint`, backwards again; and `rm -rf .ailang/cache`, which is the instrument everyone trusted.

**And one defect I shipped and the compiler caught, which is B3's lesson unlearned.** B3's
tooling-first rider says prove the rewriter lossless *before* touching the tree. I did not, and my
first fixer inserted a row **after** a `tests [...]` clause, producing
`func f() -> bool tests [((), true)] ! {…} {` — a parse error that then propagated as "parse errors in
compaction_ai" into ~20 downstream targets' logs before I read it. The fix was structural rather than
a better regex: **the tool now re-checks after every edit and reverts any edit that does not parse**,
and asserts locality and line count. That is stronger than the round-trip harness I started to build,
because it guards every edit rather than a sample.

## `make check_core` — GREEN

**Exit 0**, genuinely cache-cold (all 34): `verify_extensions: 7 booted, 0 failed`; `src/core/`
type-check **51 passed, 0 failed**. This is the first green `check_core` since the repin, and it is
the gate B1 was blocked on and B3 expected and did not get.

**Zero effect-row failures remain reachable** — B1's corrected gate, re-satisfied at the fourth
frontier. As B1's and B3's versions of this claim were true when written and then superseded, so is
mine: it is true at *this* frontier, and the frontier moves when something behind it clears.

`make CI=1 sync_packages` exits 0, so B1's drift gate is intact. `make profile_coverage` exits 0 and
still asserts three distinguishable rowless hook ids — **D5's coverable surface is intact**, verified
by diff as well: `on_describe_tools`, `on_build_system_prompt` and `on_tool_policy` are byte-identical
to HEAD.

## Tree state: 218 pass / 17 fail — above the v0.26.0 baseline

From **161 / 74** at start. B1's matched v0.26.0 baseline was **213 / 22**, so the tree now type-checks
*more* files than it did before the repin — the first point in Milestone B where that is true.

| Remaining failure | Files | Class |
|---|---|---|
| Pre-existing on v0.26.0 (`++` on strings, parse errors, `unrunnable`, code-graph fixtures, `LDR001 stub_step`) | **9** | baseline, untouched |
| `TC_ARITY_001` — smoke scripts calling `run_v2` with 10 of 13 args | **7** | **stale callers, byte-identical at HEAD**, revealed not caused |
| `IMP010: 'MkHistory' not exported` | 1 | **the sealing probe — its failure IS its pass** |

**Zero effect-row failures. Zero `images` failures. Zero `GeneratorBounds`/`ScriptedStep` failures.**
Nothing in the remaining 17 is this milestone's class, and 16 of the 17 were failing at HEAD for
reasons that had nothing to do with the repin.

**The honest sweep earned its cost.** The first post-repair sweep reported 214/21 and surfaced **four
failures I had not seen in fifteen fixer rounds**: `tools/ext_call_inventory/fixtures/`
(`control_resolved`, `form_alias`, `form_computed`, `form_reexport`) — A4's classifier-2 form fixtures,
each of which calls `ai_step` and therefore needed `Trace`. They were invisible to the round-based
loop because they *passed* at s0 and so were never in its target list. **A repair loop seeded from
the failing set cannot see what its own change breaks; only a whole-tree sweep can.** With them fixed,
`make ext_call_inventory_selftest` exits 0 and its **pinned membership block is unchanged** — which
confirms, rather than assumes, that this ABI major does not move classifier-2's answer.

## `make dst` — exit 2, and it now gets 3.4× further

**Exit 2**, read as status and not as prose. The log is **3895 lines against B3's 1153**, with 26
suite PASS markers where B3 reached the wall almost immediately. Three targets fail, **all three
previously unreachable, none of them an effect row**:

1. **`attribution_table`** — the nine stale A5 anchors above. Pre-existing at HEAD.
2. **`test_coverage`** — `src/core/prompts_test.ail: 0/6 passed`, every run
   `LDR001: module not found: src/core/prompts`. **Deterministic 0/6 across three runs**, so it is
   *not* `fb_2ad074d754cd2c25` (that one is ~6/10 and intermittent). It is a working-directory /
   module-resolution failure in `ailang test`, and it is a new, cleanly reproducible AILANG report.
3. **`test_coverage_selftest`** — `stale_skip_record` and a `named_only.ail` finding.

**`fb_2ad074d754cd2c25` is now testable and I did not test it** — its probe module
`src/core/dst_invariants.ail` was blocked on `stub_step.live_ports`, which this item cleared, exactly
as the handoff predicted it might. Retesting it is a deliberate omission, not an oversight: it is B4's
ticket-status work and it wants a clean 10-run measurement rather than a corner of this one.

## Deliberately not done, with the argument in each case

- **The seven `TC_ARITY_001` smoke scripts** (`smoke_v2_tool_read/write/build`, `_policy`,
  `_intercept`, `_factual`, `_conversation`) call `run_v2` with **10 of 13 arguments**. The call sites
  are **byte-identical at HEAD** and `run_v2`'s arity is unchanged — these are stale callers from an
  earlier milestone, revealed by the wall falling, not caused by it. Repairing them means choosing
  `max_cost_millicents`, `cost_rates` and a `StepProvider` for scripts that make **live API calls**.
  That is a behavioural decision, not a row repair, and it is not mine to make silently.
  **Two pieces of evidence say they are superseded rather than merely broken:** the sibling
  `smoke_v2_*_full_loop.ail` scripts all pass and all call `run_v2_with_scripted_ports` instead, and
  **all seven** stale callers are stale in the same way — there is no correct in-tree caller of the
  raw `run_v2` to copy. The likely right answer is deletion or migration to the scripted entrypoint,
  and both are somebody's decision to take deliberately.
- **A5's attribution table**, argued above.
- **Every package version and every `[effects] max` ceiling.** *No package declares `Trace` or `Rand`
  in its ceiling* — see the table in `packages/*/ailang.toml`. This did not block anything here, and
  I confirmed the ceiling was **not** the cause of the `compaction_ai` error (tested directly). But
  **the ABI is now at two changed rows across B1 and B2a, and the lockstep re-release is owed.** The
  version decision is the plan's, and it is stated here rather than taken.
- **WI-B2b**: the world-token widening and the two `ScriptedStep` widenings. Untouched.
- **WI-B4**: classifier re-derivation, manifest re-issue, the 13 stale `ailang 0.26.0` strings, and
  the mutation loops — now with the 113 latent rows on the list, and with the instruction that the
  loop must clear all 34 caches or it will repeat B1's inverted verdict.
- **The two v0.33.0-fixed defect workarounds.** Untouched.

## Corrections owed to the plan

1. **S9 is wrong as written.** Replacement proposed above. This is the highest-value correction in
   the report.
2. **The 191-site figure is 206.** The plan counts only `<Type> ! {row}` annotations; there are a
   further **15 lambda-form** hook assignments (`on_pre_step: \_ _ . PassThrough ! {…}`) that the grep
   misses and that the closed-row lockstep binds identically. Per type:
   `ToolHandleDecision` 52, `PreStepDecision` 62, `ResponseInterceptDecision` 45, `FinalizeDecision`
   47. **Three of the 15 were B1's un-widened cascade sites**, which is how the undercount surfaced.
3. **WI-B2's row corrections are now landed and should be struck from B2b**, leaving B2b the
   world-token widening alone. What remains of B2's "three row corrections" is: `ExtPorts.ai_step`
   ✅, `on_pre_step` ✅, `on_tool_handle` ✅ (B1), and **`on_response_intercept` / `on_solver_candidate`
   measured as NOT demanded** — so the ABI major contains four row changes' worth of prediction and
   two rows' worth of fact.
4. **`export type X = X` should be a named prohibition**, not a discovered one. Two instances, both
   record types, both silent until a construction site far away.
5. **A5's anchor discipline needs a mechanical check, not a rule.** The line-count assertion is in
   `effectfix.py` and should move somewhere durable; and the anchors themselves need re-deriving
   before the next item trusts them.

## Commit state

**Nothing is committed.** The 79 source files, `ailang.lock` and this note are working-tree changes on
`arniwesth/mot-57-execute-wi-b2-part-1`. Stating it plainly because three handoffs in a row have got
this wrong in the other direction.

## Instruments left in the scratchpad

`effectfix.py` (verdict-driven row repair: resolves module→file, refuses the ABI file and
`.packages/`, **reports rather than absorbs** any demand on a decision type, reverts any edit that
does not parse, and asserts both locality and line count), `mut2.py` (surgical row over-widening
detector, marker-scoped), `sweep.sh` (whole-tree sweep, **now genuinely cache-cold**). The line-count
guard and the all-34 clear are the two worth keeping; B4 needs both.
