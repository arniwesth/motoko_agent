# Handoff: resume project 009 once the upstream recorded-stream API has landed

Audience: a fresh agent session with no context from the spike session (2026-07-31). This handoff
is **triggered, not immediate** — most of it is wasted effort until the condition below holds.

## Trigger condition — check this first, and be strict about it

D1 requires two things, and one of them is routinely mistaken for the other:

1. A **released** AILANG version whose `std/ai` exports a recorded-stream API — one that keeps
   immediate `on_chunk` delivery *and* returns the exact ordered observed chunks.
2. This repo's toolchain **repinned** to that release.

Check (1) with a compile, not a changelog:

```bash
ailang --version
grep -c 'stepWithStreamRecorded\|chunks:' "$(dirname "$(command -v ailang)")/../std/ai.ail"
```

As of 2026-07-31 the answer on v0.31.0 is `0`. **A prototype on a fork is not this** — one exists
(see *State you inherit*) and it does not satisfy D1, no matter how green it runs.

If the trigger has not fired, the only items worth doing are **Open item 1** (the port widening,
which has no upstream dependency) and the ADR revision round. Stop after those.

## STOP — this handoff was written 2026-07-31 and Milestone A has since completed

**Everything below the trigger condition predates fourteen execution clusters and is stale.** It tells
you to do "the port widening (Open item 1)" — that is WI-A1 and it landed 2026-08-02. Written before
`dst_generator`, `dst_corpus`, the pinned canary, the twelve corpus seeds or the 700-check gate
existed, this document mentions none of them.

**Read `## What Milestone B inherits` at the end of this file instead of `## State you inherit` and
`## Sequence` below.** Those two sections are retained only as a record of what the spike session
knew; treat every anchor in them as unverified. The trigger condition above is still correct and is
still the first thing to check.

## Mission

Resume project 009 from a spike that answered its five questions and then stopped by design. The
spike proved the architecture is buildable and found six defects; none of its code merges. Your job
is the production migration the spike deliberately was not — `ADR-001`'s *Implementation handoff*
mandates a separate, source-grounded plan that "must preserve user changes and current behavior
while migrating one effect class at a time."

## Inputs (read in this order)

1. `NOTE-spike-findings-real-driver-vertical.md` — six findings (F1–F6), two measurements (M1, M2),
   and an explicit statement of what the spike does **not** establish. This is the highest-value
   input; read it before any source.
2. `spike/README.md`, section *"Vertical spike through the real driver"* — the narrative, executed
   commands and recorded output behind those findings.
3. `.agent/summaries/2026-07-31-009-real-driver-spike-and-wi-c13c-completion.md` — session
   narrative, including two hypotheses that were wrong and how they were caught.
4. `ADR-001-deterministic-test-world-architecture.md` — **note that F1–F5 are unfixed findings
   against this document.** Do not treat it as settled until the revision round has happened.
5. `PLAN-spike-real-driver-vertical.md` — what the spike was scoped to do, and its guardrails.
6. Source only as needed.

## State you inherit

| Branch | Contains | Status |
|---|---|---|
| `arniwesth/mot-44-motoko_dst_execution_primer` | all durable work | pushed; this is your base |
| `spike/009-real-driver-vertical` | throwaway driver surgery, 5 commits | pushed, **never merges** (draft PR #103) |
| `spike/motoko-009-prototype-v031` on `arniwesth/ailang` | `stepWithStreamRecorded` prototype + Go tests, on the `v0.31.0` tag | pushed |

The AILANG clone at `ailang/` is repointed: `origin` = `arniwesth/ailang`, `upstream` =
`sunholo-data/ailang` **with its push URL disabled**. Do not re-point it at upstream.

Already landed on your base branch (`89a1d67`): **WI-C13c is complete.** `ported_provider` returns
`Ports`, `C2LoopState.provider` is a `Ports`, `dispatch_step` is one branch, `ext_ports_for_provider`
is gone. If you read older notes referring to `dispatch_step`'s `LiveAI` branch as the live provider
seam, that branch no longer exists — it was unreachable and was deleted.

**PR #103 must not be merged.** A test-merge conflicts in six files and would revert `89a1d67`, a
commit the spike branch predates.

## Sequence

### 1. Widen `Ports.model_step` — do this first, trigger or no trigger

`Ports.model_step` returns `Result[StepResult, AIError]`, which structurally cannot carry an
emission log. `ported_provider` funnels **every** provider through it before the loop starts, so
adopting the upstream API without this changes nothing observable — the chunks are discarded one
layer *above* `std/ai`. This is F2, and it is the single most important thing in this handoff.

Target shape (validated by the spike):

```ailang
model_step: (string, [Message], (StreamChunk) -> () ! {IO}) -> PortExchange ! {AI, IO, Trace}
export type PortExchange = { emissions: [StreamChunk], result: Result[StepResult, AIError] }
```

No upstream dependency: widen with `emissions: []` at every construction site, behaviour-preserving,
testable entirely against `Scripted` providers. Doing it first shrinks the eventual adoption to
**one closure in `live_ports`**.

### 2. Repin the toolchain — budget for an extension-ABI major

M2 measured this: **381 effect-row edits across 71 files**, plus three widenings in
`packages/motoko-ext-abi/types.ail` (`ExtPorts.ai_step` gains `Trace`; all four `ExtensionHooks`
rows gain `Rand` and `Trace`). That file states bumping `ExtensionHooks` is a major version, so this
forces an **extension-ABI major and a coordinated re-release of every extension package**. Sequence
it before Track 1; do not discover it mid-migration.

Almost all 381 are mechanical and the compiler names each one. A compiler-driven repair loop
converged in a handful of rounds; the loop's shape is described in the summary.

### 3. Adopt the upstream API in `live_ports`

Only after 1 and 2. The prototype on the fork shows the consumer side; if upstream shipped a
different spelling, the three load-bearing properties are in `ISSUE-BODY-recorded-stream-api.md`
field 2 — the spelling does not matter, those do.

### 4. Fix the F6 cursor

`scripted_ports_from_steps` derives its script index from `assistant_count(payload)`, where payload
is post-compaction. Under a folding compactor the index **pins** and the run loops until budget
exhaustion. `scripts/dst/spike_scripted_cursor_probe.ail` demonstrates it and becomes a passing
regression test when fixed. The fix rides on step 1: once `model_step` returns a record, it can
return next-state too. `ScriptedPortsState` in `src/core/test/scripted_ports.ail` already models a
threaded cursor and is unit-tested — it is simply not wired in.

### 5. Then, and only then, write the implementation plan

Per `ADR-001`'s *Implementation handoff* and
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, author it
fresh, grounded against accepted ADRs and current HEAD. Cite M1 and M2 rather than re-estimating.

## Traps that will bite you — all hit during the spike

- **Clear the compile cache after any toolchain change.** `find . -type d -name .ailang -not -path './ailang/*' | while read d; do rm -rf "$d/cache"; done`. A stale `.ailang/cache` from a different compiler version silently poisons type resolution and reports errors against correct source. This bit twice, most recently making `rpc.ail` and `supervisor.ail` fail against source that was already right.
- **Run `long_qwen_compaction_dst` with `MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json`.** Without it compaction never fires and the scenario fails for an unrelated reason. Cost an investigation.
- **Eight scripts fail at base and are not yours**: `probe_phase_vocab_sealed`, `smoke_v2_{conversation,factual,intercept,policy,tool_build,tool_read,tool_write}`, plus five `src/examples/*`. Establish this baseline before changing anything so you can tell new breakage from old.
- **`std/ai`'s chunk callback row is closed `{IO}`; the driver's projection sink performs `{IO, Trace}`.** This works today, but a single callback *value* cannot be passed to two consumers with different rows. Reproduces against the stock API — not a prototype artifact.
- **The chunk callback must be written `func(c: StreamChunk) -> () ! {IO} { ... }`.** The `\c. ...` lambda form fails to unify against the closed row.
- **`check_core` green is not behaviour green.** The spike's worst bug — freezing the `Scripted` cursor — type-checked, kept `check_core` at 35/35, and silently failed 6 of 18 scenarios. Always run the DST gates.

## Leads already checked — do not spend time re-deriving these

- `dispatch_step`'s `LiveAI`/`Scripted` branches were unreachable. **Already deleted** in `89a1d67`.
- Structural compaction **cannot** trigger F6: `elide_old_tool_results` shortens tool-result content and never removes a message, so the assistant count is unchanged. Only a folding compactor (`compaction_ai`'s shape) does.
- `--virtual-time` does not virtualize `std/clock` (prior review, R1). Still true.
- Withholding the `Clock` capability is a **run-time** check, not build-time: `{Clock}` stays in the row and the run only dies if a read is performed. Verified with a minimal probe.
- The MCP `submit_feedback` route cannot file a GitHub issue — it queues an anonymous submission to a triage inbox, and its 10 KB body limit is under our body size.

## Loose threads

Findable, unresolved, each with enough detail to pick up cold:

1. **AILANG #386** — *"Effect-row inference regression: show() in effectful-lambda interpolation collapses effect row"*, closed — is plausibly the same family as an oddity hit during WI-C13c and **sidestepped rather than diagnosed**: moving the reduced dispatch into `session.ail` as a new `provider_step` failed with a closed-row error, while the identical shape compiled in an isolated probe *and* in `stub_step.ail`. Keeping the function in its original module was the smaller change and works. If this recurs, #386 is the first place to look.
2. **`checkpoint_enabled: false` is hardcoded** in `session_policy_init` (`src/core/session.ail:1232`), and it is the only policy constructor the exported entry points use. So `TakeCheckpoint` — and `phase_vocab.checkpoint`, which rebuilds history as `pinned ++ [summary]` — is **unreachable from every production entry point**. Found while hunting for a way to trigger F6; never dispositioned. Either it is intentionally disabled pending work, or it is a third instance of the "feature present, not wired" pattern that produced F6. Worth one ADR-level question: does D4/D7 assume checkpointing runs?
3. **`c2_initial_state`** (the no-counts wrapper in `session.ail`) has zero callers. Trivial dead code, noted only because it is the same pattern.
4. **The `ExtPorts.clock_now` seam has never been exercised** — zero call sites repo-wide (F4). Nine profile-reachable clock reads should route through it. It may not survive first contact unchanged.
5. **F5's event-vocabulary artifact is unbuilt**, and `phase_vocab.ail:561 ledger_record_name` names 3 of 34 variants. Any D7 parity invariant or acceptance row depending on the logical/display-only classification is undecidable until it exists.

## Constraints

- **Do not merge `spike/009-real-driver-vertical`, and do not merge PR #103.** Its code is throwaway by design; merging reverts `89a1d67`.
- **Do not treat the spike as clearing the D1 gate.** Five green questions and a working prototype are not a released API.
- **Do not re-point the AILANG clone's `upstream` push URL.** It is disabled deliberately.
- **F1–F5 are unfixed findings against `ADR-001`.** If the revision round has not happened, say so rather than building on decisions the spike showed are underspecified — particularly F1, where D1 does not say who owns the provider cursor and *both answers compile*.
- Prefer measurement over estimation where M1/M2 already answer the question.

---

# What Milestone B inherits — current as of 2026-08-04

Written at the close of Milestone A (fourteen clusters, WI-A1 through WI-A15). **Read this section,
not the 2026-07-31 material above.** Source: `NOTE-cluster-14-execution-report-and-plan-corrections.md`,
whose closing section was commissioned for exactly this reader.

## Where the project actually is

Milestone A is **one item short**: **WI-A17** (the `ailang test` coverage axis) is open, standalone
and off the critical path. Everything else — A1 through A16, and P6 — has landed. `make dst` is exit
0 at **700 checks** across 26 targets, roughly a 4m30s serial cost. `make check_core` is exit 0 at 51
modules. `driver_only` is at **v3**.

Milestone B's content is known and measured: a repin at **381 effect-row edits across 71 files**, an
extension-ABI major, and the `Message` migration (M1: 14 min, 28 files, 69 additive sites, 7 needing
judgement). None of that has changed. What follows is what is true at HEAD and written in no B item.

## Five things that will bite, in the order they will bite

**1. Do not run `make dst` until `make check_core` is green.** The repin turns effect rows into hard
errors *everywhere at once*, so the first honest signal after B1 is not a test failure — it is
`ailang check` failing in 71 files. Running the DST gate first produces thousands of lines of
downstream noise at roughly twenty minutes per attempt.

**2. Three sets of artifacts must be re-pinned by hand and nothing will tell you which.**

| Artifact | What it pins | Why a re-pin is not enough |
|---|---|---|
| `dst_generator.pinned_canary_v1`/`v2` | 6 rows of the generator's own stream | Deliberately **un-regenerable** — there is no `--update` flag and adding one is explicitly refused, because a canary regenerated on failure is not a canary |
| `seeded_generator_dst`'s seeds 9 / 13 / 94 | the equal-census anti-count pair, and the one S7 fixture in 260 | each has an **asserted** reason that must survive a re-sweep or be replaced by one |
| `corpus_pr_dst.fixed_bank()`'s twelve seeds | five derived selections over a 260-seed sweep | same — the reasons are asserted, not described |

**Budget a re-sweep, not a re-pin.**

**3. `live_ports` returning `emissions: []` is load-bearing in four places, and the recorded-stream
API changes all four at once**: D6.4's `StreamDelta` parity gap, `stream_parity_findings`' whole
trajectory, `provider_partial_stream_then_error`'s register entry, and the corpus's expected coverage
set. That is **one register entry closing**, and closure is asserted in both directions — so **B will
turn `corpus_pr` red, and that is correct behaviour rather than a break.**

**4. `.github/workflows/dst-corpora.yml` has never run.** It is written, its entry point is checked
to exist and its matrix is checked against the declared shard count — but no scheduler has executed
it. The first real scheduled run is an unmeasured event: 240 seeds × 4 shards against a 600 s budget
derived from a **local** 292 ms/seed. A hosted runner is not a dev container; expect the first run to
move `measured_ms_per_seed()`, and note the ceiling gates exist to make that visible rather than
silent.

**5. The two `ScriptedStep` widenings are the cheapest coverage left, and B2 is where they become
free.** They are **two** changes, not one — a provider *fault* needs an error case, a provider
*latency* needs `advance_ms` (cluster 13 separated them; earlier revisions conflated both with each
other and with D4's latency pair, which needed neither and is done). The ABI major already forces a
lockstep re-release of every extension package and already touches `ExtPorts.ai_step`, so doing them
inside that wave pays the A5 anchor cascade **once** instead of twice and closes two register entries
plus D2's completeness gap. **Doing them separately after B2 pays the cascade a second time for no
reason.** Cluster 13 predicted zero anchor cost for the latency field; that prediction is unmeasured
and B2 is the item that should measure it.

## Two deferred items with named owners

- **`max_resource_size`** — a **one-draw item, not a rebinding**. The quantity it reports has a static
  range of one value where the other four bounds report draw-derived quantities. It still costs a
  generator-version bump. Owner: **the first item that touches the generator after the corpora exist**,
  which in practice is this wave.
- **`seed_state`'s version axis** (site 22) — `in_range(salt_hash("${id}/${version}") + seed)` adds the
  version hash to the seed, so they are interchangeable and a version bump is only a seed offset.
  Fixing it moves every pinned canary row, every corpus seed and the frozen specimens' meaning at
  once. It belongs **with** the one-draw item, not before it.

## The process observation that matters most here

**Fourteen clusters produced 31 sites where two answers type-check and the wrong one is silent.
Determinism caught 0 of 31.** Every one was found by mutating something and reading *why* a row went
red — or, twice, why one **stayed green**.

Milestone B is 381 mechanical edits and an ABI major: exactly the shape that feels like it needs no
detectors, and exactly the shape where a silently-wrong edit is invisible inside 71 files of diff.
**Budget mutation loops as the cost of the wave, not as verification after it.**

## Standing rules that apply unchanged

`PLAN-implementation-deterministic-test-world.md`'s `## Standing rules` — S1 through S8 — were each
promoted from a defect and each caught later defects nothing else would have. S8's complement is the
most productive sentence in the plan: **a pinned artifact certifies exactly the paths its trajectory
walks; unwalked paths are absent, and absent reads identically to unchanged.** Every re-pin in item 2
above has that exposure.

Three filed AILANG defects have workarounds and will recur: `fb_e44ba922db1c42be` (a call in the
field-value position of a record update is not a dependency — `let`-bind it; it also has a sibling in
the head position of a cons), `fb_b39697480a4e8bbc` (an out-of-scope constructor name in a pattern
binds as a fresh variable), and `fb_2ad074d754cd2c25` (`ailang test`'s cluster harness fails
non-deterministically at ~6/10 in large modules). All are written up in `.agent/issues/`.
