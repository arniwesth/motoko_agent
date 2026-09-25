# 2026-08-05 Cluster 21: WI-C1 + WI-C2 — adopting the recorded-stream API, and proving it

## Context

Branch: `arniwesth/mot-60-execute-wi-c1-wi-c2`.

Session span: `e8577e4` → **`01f7f44`, four commits, working tree clean**. Input was
`HANDOFF-execute-c1-c2-recorded-stream-adoption.md`, executed cold against HEAD. Twenty-first code
session of project 009, and **the first of Milestone C**. Pin **v0.33.0**.

**Window: ~57 min**, `07:12Z` → `08:09Z`. The single largest saving was that D1's gate did not have
to be designed: `spike/` already held the probe, written 2026-07-25 against a local prototype. The
real work was re-pointing it at the pinned release and extending it to cover the *adoption* as well
as the API.

| Definition-of-done item | State |
|---|---|
| `.gitignore` fix + 34 caches untracked, as its own commit | **met** — `10b9583`, and the rationale it rested on turned out false |
| C1: the adoption, error path carrying its chunks | **met** — and guarded by a row proven to kill the wrong version |
| C2: five clauses of `ADR:576-578` answered **individually** | **met** — 5 rows × 2 subjects × 2 outcomes |
| The forbidden fallback visibly not-selected | **met** — permanent negative control, measured |
| All seven prose records corrected | **met** — without upgrading *blocked* to *covered* |
| S13 whole-tree sweep, cache-cold, run first | **met** — 219/17 baseline, 220/17 after |
| S9: every live cache cleared, both exclusions | **met** — and one exclusion's stated reason corrected |
| `make dst` status with each red attributed | **met** — exit 2, B4's exact two reds, no new class |

## Grounding, and it is the first handoff in six to be right

HEAD was `e8577e4` — one commit *past* the `24425cd` the handoff named, that commit being the
handoff's own update. Tree clean. Five consecutive handoffs had got this wrong; the instruction
"confirm the tree state with `git status` rather than believing any sentence in this handoff" is now
earning its keep in both directions and should stay exactly as written.

## The 34 cache files — fixed first, and S9's stated reason was wrong

`.gitignore`'s `!tools/code-graph/**` re-included everything under that path, so `git add -A` swept
the compile caches in. Fixed as `10b9583`: an explicit `tools/code-graph/**/.ailang/` ignore, plus
`git rm --cached` on the 34 files, left on disk.

**The measurement that changed the write-up: nothing reads those caches.** S9's rule text calls them
"deliberate test fixtures, read by `test_source_index.py` and `test_precision_recall.py`." Measured —
no Python under `tools/code-graph` mentions `.ailang` or `cache` at all, and both tests read the
fixtures' **`.ail` sources**. Both still pass after untracking (5 passed). So the exclusion was
protecting accidentally-committed build output while describing itself as protecting fixtures, which
is why nobody removed it in three items. S9's text is corrected in the plan.

**Verified under the exact condition that broke it twice**: after a full `make dst` — which compiles
those fixtures and rewrites their caches — `git add -A` staged **0** cache files.

## C1: two lines, and the answer that was going to be silently wrong

```ailang
let rec = stepWithStreamRecorded(model, msgs, tools_with_extensions(rt), system_prompt_cache_breakpoint(), on_chunk);
{ emissions: rec.chunks, result: rec.outcome, next_state: state }
```

**`rec.outcome` is threaded through UNMATCHED, and that is the whole decision.** The natural adoption
is `match rec.outcome { Ok(…) => …, Err(…) => … }`, and the natural error arm drops the chunks —
which `chunks` is populated on regardless of outcome. Measured with that mutant applied:

| Gate | Correct C1 | Wrong-answer mutant |
|---|---|---|
| `ailang check` | green | **green** |
| `make check_core` | 52/0 | **52/0** |
| `make driver_only` | exit 0 | **exit 0** |
| C2 **substrate** rows, both modes | PASS | **PASS** |
| C2 **adoption** rows, success | PASS | **PASS** |
| C2 **adoption** rows, partial_error | PASS | **3 FAIL** |

Only the adoption subject, only in partial-stream-then-error, sees it — precisely the clause D1 names
as its own trap.

**The declared effect row did not change.** `stepWithStreamRecorded` is `! {AI}`, same as
`stepWithStream`; `model_step` stays `! {AI, IO, Trace}`, `live_ports` stays `! {AI, Clock, Env, IO}`.
No caller moved, so B4's propagation refutation never had to be invoked.

## The headline: a substrate probe is not adoption evidence

**The most transferable finding of the run, and it fell out of building a control.**

The obvious reading of "a direct positive version of the spike" is a probe against `std/ai`. Build
only that, and you get a green gate over a broken adoption — because the substrate rows *never call
`live_ports`*. C2 therefore ships **two entry points**:

- `main_substrate` — `std/ai.stepWithStreamRecorded` driven directly. Proves the API, on the **pinned
  release** rather than the prototype the spike used. This is what D1 literally asks for.
- `main_adoption` — `stub_step.live_ports`' own `model_step` closure. Proves C1. It takes the same
  `Ports` record the driver takes at `session.ail:882` and calls the same field the loop calls.

Mutant 1 is the justification: every substrate row green, adoption rows red. **Where an item adopts an
external API, the gate must drive *our* closure.** This generalises past streaming and should bind C5.

## D1's five clauses, answered separately

`make recorded_stream`. Five rows, two subjects, two outcomes — deliberately not a conjunction, per
cluster 12's rule that a row asserts its own fact.

| # | Clause | Observation that settled it |
|---|---|---|
| 1 | immediate projection | Sandwich: all 5 `LIVE` lines strictly between `CALL begin` and `RETURNED`, ordinary sequenced IO in one process |
| 2 | exact returned-log parity | `count=5 order=c1-alpha\|c2-beta\|rep\|rep\|c5-omega\|` — count and order asserted **separately**, since count alone passes under reordering |
| 3 | success | `MODE=success` → `OUTCOME ok stop`, all 5 chunks returned |
| 4 | partial-stream-then-error | 5 real SSE deltas, then the chunked body terminated mid-flight and the socket dropped → `OUTCOME err ConnectionFailed`, **all 5 pre-failure chunks still returned** |
| 5 | no duplicate delivery | projected == supplied == returned == 5, and the fixture's **adjacent repeat** means a de-duplicating implementation returns 4 |

**First time these have been answered against a pinned release rather than a prototype**, which is the
specific thing D1 asks for and the specific thing `spike/` says it could not supply.

### The forbidden fallback is measurably rejected, not assumed

D1 rejects delayed projection outright. A gate that cannot tell it apart from immediate projection
does not *enforce* that rejection — it merely happens to agree with it, and would keep agreeing after
someone switched. So `main_delayed_projection_control` **is** the rejected design (no-op callback
sink, every chunk projected off the returned log afterwards), and the runner asserts it **fails** the
sandwich. It does: `first_live=7 > returned=6`.

The control is **newly possible**: before the recorded-stream API there was nothing to project late
*from*, so this fallback was not expressible and could not be controlled against.

## The stub's chunk count: measured at TWO, and it decided the design

```
callback ContentDelta({"kind":"Wait"})
callback Usage(in=0,out=0)
returned chunk count = 2
```

`--ai-stub` is a provider without native streaming, so per `std/ai`'s contract it fires the callback
exactly twice and always returns `Ok`.

- **Provable from the stub:** clause 3, and weak forms of 1, 2, 5 on two elements.
- **Not provable at all:** clause 4 — the stub cannot fail part-way. Ordering is barely exercised on
  two chunks of different *variants*; duplication not at all.

**So C2 does not use `--ai-stub`**, the only target in `make dst` that doesn't. It stands up a real
native SSE endpoint on loopback with a five-element order-distinguishing sequence carrying a
deliberate adjacent repeat. Reported as a measured substrate property rather than absorbed: **a
two-chunk pass would have looked identical to a real one in the output.**

The runner **asserts the fixture's own adequacy** rather than describing it (S7): it reads `DELTAS`
out of the server so the expectation cannot drift, and fails outright if the sequence is under 3
chunks or carries no adjacent repeat.

## The gate is load-bearing in three directions

Mutation-tested, **each mutant killed by a distinguishable row set** (S8's sequenced-clause form):

| Mutant | Result |
|---|---|
| Natural wrong adoption (`match` on outcome, `Err` drops chunks) | **3 rows red, partial_error only** |
| Revert C1 entirely (`stepWithStream` + `emissions: []`) | **6 rows red, both modes** |
| Delayed projection (permanent control) | **sandwich inverts** |

And it caught a defect of its own author on first run: the runner passed an **absolute** path to
`ailang run`, which fails `MOD010`. The vacuity guard — *"probe produced no evidence, every row below
would be vacuous"* — fired instead of printing four screens of silent passes.

## The seven prose records, corrected without upgrading blocked to covered

All seven rewritten; none gates anything, which is the class B4 identified as dangerous. **Three said
"externally blocked", which stopped being true the day v0.33.0 shipped — before this item started.**

The distinction the handoff asked to preserve is preserved in every one: **the log is PRODUCED; it has
NO DRIVER CONSUMER.** Not "unblocked", not "covered". `session.ail`'s is the sharpest — it used to be
empty at the source, it is now non-empty and that line drops it: **the gap moved from producer to
consumer.**

## The D4 cascade fired on a PURE COMMENT, refuting a standing claim

Three anchors moved: `stub_step.ail` 163 → 182, `session.ail` 2360 → 2365 and 2470 → 2475. **Every one
moved because this item added comment lines above them.**

Re-derived, and as at B4 it was **not a judgement**: `now()` is unique in `stub_step.ail`;
`session.ail` has exactly four `ports.clock_now(` sites. One candidate each. Per B4's correction 6,
worth saying plainly rather than claiming credit for a decision that did not exist.

Cascade paid in full — `anchors.sh`, `dst_attribution_table.ail`, and every referring `site_key` in
`dst_profile.ail`, `dst_driver_only.ail`, `profile_definition_dst.ail`. **`driver_only` re-issued
v4 → v5**, identity re-recorded to `c0fbf10/sha256:e201c1da…`. **Coverage did not move**: install list
still empty, waived set still every conditional class, no hook classification changed, catalogue still
`fault-catalogue/2`.

**The finding: `driver_only`'s own v3 note claims half this cascade is avoidable by care** — "insert
below the anchor and widen import lists in place". **WI-C1 refutes it.** The edit was a comment
explaining the adoption, placed above `live_ports` where a reader of `live_ports` will find it.
*Insert below the anchor* is not available to a comment whose whole job is to be read before the thing
it describes. Avoiding the cascade would mean writing documentation in the wrong place — a worse trade
than re-issuing a profile. Recorded at the site; three consecutive items have now paid it.

## Sites where two answers type-checked and one was silently wrong: 2

**Counter note: the handoff says 39, B4's report says 39 → 43.** Reports are the record, so the base is
43 and this run makes it **45**. Determinism has still caught none.

1. **`live_ports`' error branch.** Green under `ailang check`, `check_core`, `driver_only`, and every
   substrate row of C2's own probe. Written correctly, **now guarded** by a row proven to kill it.
2. **`stub_step.ail:163` inside HISTORICAL prose.** The mechanical anchor `sed` rewrote `:163` → `:182`
   everywhere, including two notes that record *past* state (`driver_only`'s v3 note, `ports.ail`'s
   technique note). Both values well-formed, both read like the same kind of fact, one a false claim
   about history, **nothing goes red**. Caught by reading the diff. This is B4's frozen-v1-specimen
   defect exactly — *a live claim and a historical record look identical* — one item later in a
   different file class. Fixed in `12577c2`.

The transferable rule: **a global `sed` over a line-number reference is safe for `site_key` data and
unsafe for prose, because prose has tense.**

## Recorded bindings: decided versus discovered

**Discovered** — a tool, the compiler or a gate forced it: the stub's chunk count of 2; all three moved
anchors and the new content hash; that `--ai-stub` cannot serve C2 at all; that `ailang run` rejects an
absolute path with `MOD010`; that delayed projection **is** distinguishable (built expecting to have to
report a D1-level finding if not); that no Python reads the cache fixtures; that the spike's probe
compiles unchanged against v0.33.0 with no `AILANG_SRC` redirection now the API is released.

**Decided** — a human chose: two subjects rather than one (the item's main design decision, justified
by mutant 1); a five-chunk fixture with an adjacent repeat rather than the spike's two; a *permanent*
delayed-projection control rather than an assertion; `recorded_stream` joining `make dst` despite a
python3 + loopback-port dependency; a new server under `scripts/dst/` rather than mutating the spike's
dated record; **not** populating `emissions` at the two scripted `play_chunks` sites (the deterministic
half of D1's parity claim — C3's, and named at `ports.ail` rather than left to be rediscovered);
bumping `driver_only` to v5; keeping S9's exclusion with its rationale rewritten to what is true.

## Gate state

- **`make check_core` — EXIT 0**, 52 passed / 0 failed, cache-cold.
- **Whole-tree sweep — 220 pass / 17 fail**, cache-cold with S9's corrected command and both
  exclusions. **Failing set byte-identical to B4's**, verified by `diff`. 220 rather than 219 because
  `recorded_stream_dst.ail` is new.
- **`make dst` — EXIT 2, the SAME TWO reds as B4.** No target went red in this item; no new class.
  - `test_coverage` — `prompts_test.ail` 6/6 failed + a `stale_skip_record`. Pre-existing;
    module-resolution failure in `ailang test`, measured deterministic at B2a.
  - `test_coverage_selftest` — `stale_skip_record` on *"Named test blocks not yet implemented"* plus a
    `named_only.ail` finding. Pre-existing.
- **`make recorded_stream` — exit 0.** 23 clause rows plus the negative control.
- `anchors` / `attribution_table` / `driver_only` / `profile_definition` / `profile_coverage` /
  `world_state` — **all exit 0** after the re-issue.
- **Tree clean, 0 tracked `.ailang/cache` paths**, verified *after* a full `make dst`.

## Does the emission log have a consumer? **No.**

Stated plainly, because C2's green must not read as parity coverage:

- `live_ports` **produces** a real ordered non-empty log on both outcomes.
- `session.ail`'s `exchange.emissions` **still goes nowhere.**
- `stream_parity_findings` is still exercised only by **CONSTRUCTED** executions.
- The scripted adapters still report `emissions: []` even where they play chunks.

**D1's substrate gate is answered. D6.4's parity obligation is not discharged.** Different claims, and
only the first is this item's. **That sentence is WI-C3's to change** — and C3 is now unblocked in a
way it has never been: the thing it consumes exists.

## Corrections owed to the plan

1. **S9's `tools/code-graph` rationale was false** and is corrected in the plan. No tracked
   `.ailang/cache` paths remain anywhere in the repo, so the exclusion means only what it says.
2. **A direct probe of an upstream API is NOT evidence that the adoption of it works.** Should bind C5.
3. **`--ai-stub` fires the callback exactly twice and always succeeds.** Any future gate claiming to
   exercise chunk ordering, duplication or provider failure through it is claiming something the
   substrate cannot deliver.
4. **The line-number anchor cascade is not half-avoidable**, and `driver_only`'s v3 note saying so is
   refuted at the site.
5. **A global `sed` over a line-number reference is safe for data and unsafe for prose.**
6. **The counter in the handoff (39) disagrees with B4's report (43).** Base is 43; this run makes 45.
7. **The two scripted `play_chunks` sites are a live, named loss channel**, not a settled `[]`.

## Deliberately not done

- **WI-C3** — the parity invariant, and the item that gives the log a reader. Explicitly next.
- **WI-C4, the name gate.** **No target gained the "DST" or "simulation" name.** B4's `on_budget_plan`
  argument stands: no extension is installable under D5 while that hook carries the ABI's closed
  `! {Env, FS}` row, so `driver_only` still covers nothing *provably*. C2 going well does not move it.
- **WI-C5** — `proc_exec`/`env_get` widening and the declared-versus-performed detector.
- The `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds. Unchanged, still owed, still the plan's.
- Populating `emissions` at the scripted construction sites — C3's.

## Commits

| | |
|---|---|
| `10b9583` | `chore:` stop tracking AILANG compile caches under `tools/code-graph` |
| `c0fbf10` | `feat(009):` WI-C1 adopt the recorded-stream API, WI-C2 prove it |
| `12577c2` | `docs(009):` pin the attribution ref, un-falsify two historical anchor notes |
| `01f7f44` | `docs(009):` WI-C1+C2 execution report |

Full execution report: `.agent/projects/009_motoko_dst_execution/NOTE-c1-c2-execution-report-and-plan-corrections.md`
