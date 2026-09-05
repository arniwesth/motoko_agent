# WI-C1 + WI-C2 execution report — the recorded-stream adoption, and D1's gate finally answered

Twenty-first calibration run, and the first of Milestone C. Written against HEAD `12577c2`, branch
`arniwesth/mot-60-execute-wi-c1-wi-c2`.

## Window

**~57 minutes** wall-clock: `2026-08-05T07:12Z` → `2026-08-05T08:09Z`. The single largest saving was
that the D1 gate did not have to be designed — **`spike/` already contained the probe**, written
2026-07-25 against a local prototype, and the item's real work was re-pointing it at the pinned
release and extending it to cover the adoption as well as the API.

**Grounding, and this is the first handoff in six to get commit state right.** `git status` clean,
HEAD `e8577e4` — one commit *past* the `24425cd` the handoff names, that commit being the handoff's
own update. The instruction to confirm with `git status` rather than believe the prose is now
earning its keep in both directions and should stay exactly as written.

## The 34 cache files, fixed first, and the stated rationale for S9 was wrong

Fixed as `10b9583`, before any C1 work, as the handoff directed. `.gitignore` gained
`tools/code-graph/**/.ailang/`; the 34 files were `git rm --cached`'d and left on disk.

**The measurement that changed the write-up: nothing reads those caches.** S9's rule text says they
are "deliberate test fixtures, read by `test_source_index.py` and `test_precision_recall.py`."
Measured — no Python under `tools/code-graph` mentions `.ailang` or `cache` at all, and both tests
read the fixtures' **`.ail` sources** (`build_source_index` walks the directory;
`test_sample3_precision_recall` reads `fixtures/sample3`). Both still pass after untracking (5
passed). **So the exclusion was protecting accidentally-committed build output while describing
itself as protecting fixtures**, which is why nobody removed it in three items. S9's text is
corrected in the plan.

**The fix is verified under the exact condition that broke it twice.** After a full `make dst`, which
compiles those fixtures and rewrites their caches, `git add -A` staged **0** cache files, and
`git ls-files | grep -c '.ailang/cache'` is **0**. Previously that sequence is what put 34 files in
git at both `7bca61c` and `072bb05`.

## C1: the adoption, and the answer that was going to be silently wrong

Two lines and one import symbol at `src/core/test/stub_step.ail`, exactly as WI-A1's port widening
predicted:

```ailang
let rec = stepWithStreamRecorded(model, msgs, tools_with_extensions(rt), system_prompt_cache_breakpoint(), on_chunk);
{ emissions: rec.chunks, result: rec.outcome, next_state: state }
```

**`rec.outcome` is threaded through UNMATCHED, and that is the whole decision.** The natural
adoption is `match rec.outcome { Ok(…) => …, Err(…) => … }`, and the natural error arm drops the
chunks. **Measured, not argued** — with that mutant applied:

| Gate | Correct C1 | The wrong-answer mutant |
|---|---|---|
| `ailang check src/core/test/stub_step.ail` | green | **green** |
| `make check_core` | 52 passed, 0 failed | **52 passed, 0 failed** |
| `make driver_only` | exit 0 | **exit 0** |
| C2 probe, **substrate** rows (both modes) | all PASS | **all PASS** |
| C2 probe, **adoption** rows, success mode | all PASS | **all PASS** |
| C2 probe, **adoption** rows, partial_error | all PASS | **3 FAIL** |

**Only the adoption subject, and only in partial-stream-then-error, sees it.** That is precisely the
clause D1 names as its own trap, and it is a stronger result than "the probe catches the mutant":
the *substrate* probe stays green because it never calls `live_ports`. Anyone who builds only the
direct API probe — which is what "a direct positive version of the spike" most naturally means —
gets a green gate over a broken adoption.

**On the handoff's stop condition — the declared effect row did NOT change.** `stepWithStreamRecorded`
is `! {AI}`, the same row as `stepWithStream`; `model_step` stays `! {AI, IO, Trace}` and `live_ports`
stays `! {AI, Clock, Env, IO}`. No caller above it moved. B4's refutation (a wider function row
propagates to callers) did not need to be invoked.

## C2: D1's five clauses, answered separately

`make recorded_stream` → `scripts/dst/run_recorded_stream_probe.sh`. **Five clauses, five rows, two
subjects, two outcomes** — deliberately not a conjunction, per cluster 12's rule that a row asserts
its own fact.

| # | Clause | Answer | The observation that settled it |
|---|---|---|---|
| 1 | **immediate projection** | **PROVEN**, and the rejected alternative is *measurably* rejected | Sandwich: `CALL begin` printed before the call, `RETURNED` after it, both ordinary sequenced IO in one process. All 5 `LIVE` lines fall strictly between. A `LIVE` line there can only have been written by the callback *during* the call. |
| 2 | **exact returned-log parity** | **PROVEN**, count and order asserted **separately** | `RETURNED count=5 order=c1-alpha\|c2-beta\|rep\|rep\|c5-omega\|` against the sequence read out of the fixture server. Count alone would pass under reordering, so it is two rows. |
| 3 | **success** | **PROVEN** | Server `MODE=success` → `OUTCOME ok stop`, with all 5 chunks returned. |
| 4 | **partial-stream-then-error** | **PROVEN**, on a genuinely broken stream | Server `MODE=partial_error` emits 5 real SSE deltas then terminates the chunked body mid-flight and drops the socket → `OUTCOME err ConnectionFailed`, **with all 5 pre-failure chunks still returned**. |
| 5 | **no duplicate delivery** | **PROVEN**, and it can distinguish de-duplication | projected == supplied == returned == 5. The fixture carries an **adjacent repeat** (`rep`, `rep`), so an implementation returning a set, or de-duplicating, returns 4 and fails. |

All five hold **on both outcomes**, for **both subjects** — `std/ai.stepWithStreamRecorded` driven
directly, and `live_ports`' own `model_step` closure. **This is the first time these clauses have been
answered against a pinned release rather than a local prototype**, which is the specific thing D1 asks
for and the specific thing `spike/` says it could not supply.

### The forbidden fallback is visibly not-selected, and that is a permanent control

D1 rejects delayed projection outright. **A gate that cannot tell it apart from immediate projection
does not enforce that rejection — it merely happens to agree with it, and would keep agreeing after
someone switched.** So it is measured rather than assumed: `main_delayed_projection_control` **is**
the rejected design — a no-op callback sink, every chunk projected off the returned log after the
call — and the runner asserts it **FAILS** the sandwich. It does: `first_live=7 > returned=6`. Clause
1 is therefore a real test and not an instrument that certifies everything.

Worth noting the control is **newly possible**. Before the recorded-stream API there was nothing to
project late *from*, so this fallback was not expressible and could not be controlled against.

## The stub's chunk count: measured at TWO, and it decided the design

Measured directly, not inferred from the docstring:

```
callback ContentDelta({"kind":"Wait"})
callback Usage(in=0,out=0)
returned chunk count = 2
```

**`--ai-stub` is a provider without native streaming**, so per `std/ai`'s own contract it fires the
callback exactly twice and always returns `Ok`.

**What that lets a stub-driven C2 prove:** clause 3 (success), and weak forms of 1, 2 and 5 on a
two-element sequence.

**What it cannot prove at all:** clause 4 — partial-stream-then-error is unreachable, because the stub
cannot fail part-way. And ordering is barely exercised on two chunks of different *variants*, while
duplication is not exercised at all.

**So C2 does not use `--ai-stub`**, which every other target in `make dst` does. It stands up a real
native SSE endpoint on loopback (`scripts/dst/recorded_stream_server.py`, derived from the spike's)
with a five-element, order-distinguishing sequence carrying a deliberate adjacent repeat. Per the
handoff's instruction, this is reported as a measured substrate property rather than absorbed: **a
two-chunk pass would have looked identical to a real one in the output**, and that is the reading this
milestone exists to stop.

The runner **asserts the fixture's own adequacy** rather than describing it (S7): it reads `DELTAS`
out of the server so the expectation cannot drift, and it fails outright if the sequence has fewer
than 3 chunks or carries no adjacent repeat.

## The gate is load-bearing in three directions

`make recorded_stream` is mutation-tested, and **each mutant is killed by a distinguishable row set**
(S8's sequenced-clause form):

| Mutant | Result |
|---|---|
| The natural wrong adoption (`match` on outcome, `Err` drops chunks) | **3 rows red, partial_error mode only** — parity count, parity order, `err_branch_keeps_chunks` |
| Revert C1 entirely (`stepWithStream` + `emissions: []`) | **6 rows red, BOTH modes** |
| Delayed projection (permanent control) | **immediate-projection sandwich inverts** |

And it caught a real defect of its own author on first run: the initial runner passed an **absolute**
path to `ailang run`, which fails `MOD010`. The vacuity guard — *"probe produced no evidence, every
row below would be vacuous"* — fired instead of printing four screens of silent passes. That guard
exists because absent reads identically to unchanged, and it earned its place immediately.

## The seven prose records, corrected without upgrading blocked to covered

All seven rewritten. **Three said "externally blocked", which stopped being true the day v0.33.0
shipped — before this item started.** None of the seven gates anything, which is the class B4
identified as the dangerous one.

The distinction the handoff asked to preserve is preserved in every one: **the log is PRODUCED; it has
NO DRIVER CONSUMER.** Not "unblocked", not "covered".

| Site | Now says |
|---|---|
| `src/core/ports.ail` | WI-A1's `emissions: []` prediction held exactly; C1 spent it. Log produced, no consumer. Also names the two scripted sites that *play* chunks and still report none — this field's own loss channel one layer down, and C3's. |
| `src/core/session.ail` | Still no consumer, **but the reason changed**: it used to be empty at the source, it is now non-empty and this line drops it. **The gap moved from producer to consumer.** |
| `src/core/dst_invariants.ail:78` | No longer `[]` on every path; the paragraph survives for an unchanged reason — a real run still cannot produce the executions the check selects among. |
| `src/core/dst_invariants.ail:635` | "NO LONGER EXTERNALLY BLOCKED… What remains is OURS and is deferred by choice." |
| `src/core/dst_corpus.ail:986` | "NOT externally blocked" — names the two remaining obstacles as ours. |
| `src/core/dst_fault_catalogue.ail:333` | The external half removed; the partial-stream case now proven against a real broken stream. |
| `scripts/dst/corpus_pr_dst.ail:82` | "NO LONGER externally blocked… Ours now, and WI-C3's." |

## The D4 cascade fired on a PURE COMMENT, and that refutes a standing claim

**Three anchors moved: `stub_step.ail` 163 → 182, `session.ail` 2360 → 2365 and 2470 → 2475.** Every
one moved because this item added **comment lines** above them.

**Re-derived, and as at B4 it was not a judgement.** `now()` is unique in `stub_step.ail`;
`session.ail` has exactly four `ports.clock_now(` call sites. One candidate each, so no choice was
available — and per B4's correction 6 that is worth saying plainly rather than claiming credit for a
decision that did not exist.

Cascade paid in full: `anchors.sh`, `dst_attribution_table.ail`, and every referring `site_key` in
`dst_profile.ail`, `dst_driver_only.ail` and `profile_definition_dst.ail`. **`driver_only` re-issued
v4 → v5**, identity re-recorded to
`c0fbf10/sha256:e201c1da675c4fa0a295ce80ea8d66f565ffae76fbb676634fe3933360404d60`. **Coverage did not
move**: install list still empty, waived set still every conditional class, no hook classification
changed, catalogue still `fault-catalogue/2`.

**The finding: `driver_only`'s own v3 note claims half this cascade is avoidable by care** — "insert
below the anchor and widen import lists in place". **WI-C1 refutes it.** The edit that moved the
anchor was a comment explaining the adoption, placed above `live_ports` where a reader of `live_ports`
will find it. *Insert below the anchor* is not available to a comment whose whole job is to be read
before the thing it describes. **Avoiding the cascade would mean writing documentation in the wrong
place, which is a worse trade than re-issuing a profile.** Recorded at the site. Three consecutive
items have now paid this; the case for a coordinate-independent anchor is no longer speculative.

## Sites where two answers type-checked and one was silently wrong: 2

**On the counter itself — the handoff says "39 across twenty runs", but B4's report records "39 → 43".
43 is the number that follows from the reports; the handoff appears to restate B4's pre-item figure.
Taking 43 as the base, this run makes it 45. Determinism has still caught none.**

1. **`live_ports`' error branch.** Both forms type-check; the wrong one passes `check_core`,
   `driver_only`, and every substrate row of C2's own probe. **Written correctly, and now guarded** by
   a row proven to kill it.
2. **`stub_step.ail:163` inside HISTORICAL prose.** The mechanical anchor update rewrote `:163` →
   `:182` everywhere, including two notes that are records of *past* state — `driver_only`'s v3 note
   and `ports.ail`'s technique note. Both values are well-formed, both read like the same kind of
   fact, and one is a false claim about history. **Nothing goes red.** Caught by reading the diff, not
   by a gate. This is B4's frozen-v1-specimen defect exactly — *a live claim and a historical record
   look identical* — recurring one item later in a different file class. **Fixed in `12577c2`.**

**Both are the same shape as the seven prose records**: a versioned artifact whose text nothing
checks. The mechanical-edit lesson is narrow and transferable: **a global `sed` over a line-number
reference is safe for `site_key` data and unsafe for prose, because prose has tense.**

## Recorded bindings: decided versus discovered

**Discovered — a tool, the compiler or a gate forced it and I transcribed:**

1. **The stub's chunk count is 2.** Measured with a throwaway probe before designing anything.
2. **All three moved anchors**, and the content hash `sha256:e201c1da…`. `make anchors` named them.
3. **`--ai-stub` cannot serve C2 at all** — follows from (1) plus the always-`Ok` behaviour.
4. **`ailang run` rejects an absolute path with `MOD010`.** The runner's own vacuity guard found it.
5. **Delayed projection is distinguishable.** Built the control expecting to have to report a D1-level
   finding if it was not; it is (`first_live=7 > returned=6`).
6. **No Python in `tools/code-graph` reads the cache fixtures**, which falsified S9's stated rationale.
7. **The spike's probe compiles unchanged against v0.33.0** — `ThinkingDelta` still exists, `Message`
   still takes `images`/`tool_calls`, and no `AILANG_SRC` redirection is needed now the API is released.

**Decided — a human chose:**

1. **Two subjects rather than one.** The substrate probe alone would have certified C1 without testing
   it. This is the item's main design decision and mutant 1 is its justification.
2. **A five-chunk fixture with an adjacent repeat**, rather than accepting the spike's two. The repeat
   is what makes clause 5 able to reject de-duplication.
3. **A permanent delayed-projection control**, rather than asserting immediate projection holds.
4. **`recorded_stream` joins `make dst`**, accepting a python3 + loopback-port dependency in an
   otherwise hermetic target set. D1's gate is not worth having as a script nobody runs.
5. **A new server under `scripts/dst/` rather than mutating the spike's.** The spike is a dated record
   whose README quotes its two-delta results; changing its fixture would falsify it.
6. **NOT populating `emissions` at the two scripted `play_chunks` sites.** They play chunks and report
   none — the same loss channel one layer down — but that is the *deterministic* half of D1's parity
   claim, and it belongs to the item that builds the reader. Named at `ports.ail` rather than left for
   someone to rediscover.
7. **Bumping `driver_only` to v5** rather than leaving the table stale.
8. **Keeping S9's `tools/code-graph` exclusion** even though its stated reason was false — it saves
   recompiling fixtures — with the rationale rewritten to what is actually true.

## Gate state

- **`make check_core` — EXIT 0.** `src/core/` **52 passed, 0 failed**, cache-cold.
- **Whole-tree sweep — 220 pass / 17 fail**, cache-cold with S9's corrected command and both
  exclusions. **The failing set is byte-identical to B4's**, verified by `diff`, member for member.
  220 rather than 219 because `recorded_stream_dst.ail` is new.
- **`make dst` — EXIT 2, with the SAME TWO red targets as B4.** No target went red in this item; no
  new class appeared.
  - **`test_coverage`** — `src/core/prompts_test.ail` 6 of 6 failed, plus a `stale_skip_record`.
    Pre-existing; B2a measured it deterministic across three runs, a module-resolution failure in
    `ailang test`, not a repin or adoption artifact.
  - **`test_coverage_selftest`** — `stale_skip_record` on *"Named test blocks not yet implemented"*
    and a `named_only.ail` finding. Pre-existing.
- **`make recorded_stream` — exit 0.** 23 clause rows across two subjects and two outcomes, plus the
  negative control.
- **`make anchors` / `attribution_table` / `driver_only` / `profile_definition` / `profile_coverage` /
  `world_state` — all exit 0** after the re-issue.
- **Working tree clean, 0 tracked `.ailang/cache` paths**, verified *after* a full `make dst`.

## Does the emission log have a consumer? **No.**

**Stated plainly, because C2's green must not be read as parity coverage.** At the end of this item:

- `live_ports` **produces** a real, ordered, non-empty emission log on both outcomes.
- `session.ail`'s `exchange.emissions` **still goes nowhere.** No driver code reads the field.
- `dst_invariants.stream_parity_findings` is still exercised only by **CONSTRUCTED** executions, not
  by selecting among executions a real run can produce.
- The scripted adapters a seeded run drives still report `emissions: []` even where they play chunks.

**D1's substrate gate is answered. D6.4's parity obligation is not discharged.** The two are different
claims, and only the first is this item's. **That sentence is WI-C3's to change**, and C3 is now
unblocked in a way it has never been: the thing it consumes exists.

## Corrections owed to the plan

1. **S9's `tools/code-graph` rationale was false and is corrected in the plan.** Those caches are not
   read by any test; they were accidentally committed build output, three times. `.gitignore` now
   ignores them explicitly and **there are no tracked `.ailang/cache` paths anywhere in the repo** —
   so the exclusion means only what it says.
2. **A direct probe of an upstream API is NOT evidence that the adoption of it works.** Measured: the
   wrong adoption is green under `ailang check`, `check_core`, `driver_only`, and **every substrate
   row of C2's own probe**. Where an item adopts an external API, the gate must drive *our* closure.
   This generalises past streaming and should bind C5.
3. **`--ai-stub` fires the callback exactly twice and always succeeds.** Any future gate that claims
   to exercise chunk ordering, duplication or provider failure through `--ai-stub` is claiming
   something the substrate cannot deliver. Two chunks and a real stream look identical in the output.
4. **The line-number anchor cascade is NOT half-avoidable, and `driver_only`'s v3 note saying so is
   refuted at the site.** A comment above the anchored function moves it, and comments belong above
   what they describe. Three items have paid this.
5. **A global `sed` over a line-number reference is safe for data and unsafe for prose**, because
   prose has tense. Two historical notes were falsified this way and neither would have gone red.
6. **The counter in the handoff (39) disagrees with B4's report (43).** Reports are the record; the
   base is 43 and this run makes it 45.
7. **The two scripted `play_chunks` sites are a live, named loss channel**, not a settled `[]`. They
   are the deterministic half of D1's parity claim and C3 needs them.

## Deliberately not done

- **WI-C3** — the streaming-trace parity invariant, and the item that gives the emission log a reader.
  Explicitly next.
- **WI-C4, the name gate.** **No target gained the "DST" or "simulation" name.** D10 gates the name on
  the full acceptance table, and B4's `on_budget_plan` argument stands unchanged: no extension is
  installable under D5 while that hook carries the ABI's closed `! {Env, FS}` row, so `driver_only`
  still covers nothing *provably*. C2 going well does not move that.
- **WI-C5** — `proc_exec`/`env_get` widening and the declared-versus-performed detector.
- **The `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.** Unchanged, still owed, still the plan's.
- **Populating `emissions` at the scripted construction sites** — argued above, C3's.
