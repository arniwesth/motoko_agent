# Handoff: execute WI-C1 + WI-C2 — adopt the recorded-stream API, and prove it

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**Milestone B closed 2026-08-04.** `check_core` green at 52 modules, tree at 219 pass / 17 fail,
`make dst` down to two red targets. **Confirm the tree state with `git status` rather than believing
any sentence in this handoff** — five consecutive handoffs restated commit state and all five were
wrong. What I measured, so you can check it cheaply: B4's *docs* are committed (`b1dd860`), and
**B4's source work is not** — 35 modified files plus 3 untracked, timestamped 2026-08-04. The two
untracked `tools/code-graph/tests/fixtures/*/.ailang/` directories are the unfixed `.gitignore:54`
trap, not your work and not to be committed.

**Read first:** `NOTE-b4-execution-report-and-plan-corrections.md`, then the plan's
`## Standing rules` — **S13 is new** and it is the rule this item is most likely to violate.

**Read second, and this is not optional:** the ADR's **D1 substrate gate**
(`ADR-001:543-580`) and its acceptance clauses. Nobody has read that table in a long while, and
this is the item it was written for.

## Mission

**Adopt `stepWithStreamRecorded` in `live_ports` (C1), and build the positive integration probe that
proves it (C2).**

**The upstream gate has cleared, and I verified the substrate rather than the release note.**
`/home/motoko/.local/share/ailang/std/ai.ail:339-362` on v0.33.0 exports:

```ailang
export type RecordedStream = { chunks: [StreamChunk], outcome: Result[StepResult, AIError] }
export func stepWithStreamRecorded(
  model, messages, tools, cache_breakpoints, on_chunk: (StreamChunk) -> () ! {IO}
) -> RecordedStream ! {AI}
```

That is **exactly the spike's candidate 1** — "a modeled provider result that preserves immediate
projection and returns the ordered chunks" — the representation `ADR:548` describes and then says
*"but the real API exposes no such result."* It exists now. The callback row is untouched, so none
of the rejected fallbacks (`SharedMem` recorder, delayed projection) are in play.

## The two items are one cluster, and the reason is measured

**I ran C1's edit.** It is two lines plus one import symbol:

```ailang
let rec = stepWithStreamRecorded(model, msgs, tools_with_extensions(rt), system_prompt_cache_breakpoint(), on_chunk);
{ emissions: rec.chunks, result: rec.outcome, next_state: state }
```

at `src/core/test/stub_step.ail:150-151`. With it applied, cache-cold:

| Gate | Before C1 | With C1 applied |
|---|---|---|
| `ailang check src/core/test/stub_step.ail` | green | **green** |
| `make check_core` | 52 passed, 0 failed | **52 passed, 0 failed** |
| `make driver_only` | exit 0 | **exit 0** |

**Identical. The entire deliverable of C1 is invisible to every gate in the tree.** Source restored,
`git diff` on that file empty.

So C1 shipped as its own cluster would be a commit that provably certifies nothing — the exact shape
S8 and S13 are about. **Do both, in one session.** C2 is not a follow-up; it is C1's only evidence.

## The rule you will break by accident

**D1's named trap was disarmed by A1 in the wrong place, and it is still live one layer up.**

The trap as D1 states it: adopting the API without widening the port first carries an empty emission
log through the adoption. A1 widened the port, so the plan records the trap as handled. **It is not.**
Read `src/core/session.ail:2071`, which says it in as many words:

> `exchange.emissions` rides along but **has no driver consumer yet**

A1 widened the *channel*. It did not build a *reader*. After C1 the log is non-empty and still goes
nowhere. And `dst_invariants.ail:82` confirms the consumer side independently:
`stream_parity_findings` is exercised by **CONSTRUCTED** executions, "not by selecting among the
executions a real run can produce."

**The consequence: C1 admits two type-checking answers with a silent wrong one.** The API's own
docstring marks where:

> `chunks` is populated on **BOTH** outcomes — a stream that fails part-way still returns every chunk
> observed before the failure, **which is the case a deterministic recorder most depends on**

The natural adoption is `match rec.outcome { Ok(…) => …, Err(…) => … }`, and the natural error branch
drops the chunks. That version compiles, passes `check_core`, passes `driver_only`, and **defeats
precisely the clause D1 names** — partial-stream-then-error parity. It would be finding #40 on a
counter that determinism has caught none of.

**Why no test catches it:** 17 of the 18 `emissions:` construction sites are scripted providers,
where `[]` is *correct*. Only `live_ports` is live, and nothing in the suite runs it. Do not read a
green tree as adoption evidence — **that is the reading the whole milestone is meant to stop.**

## C2's starting line moved, in both directions

**Favourably, from B2b.** `ScriptedStep` gained `error_code`/`error_message` (`ports.ail:81-97`), so
`provider_error_retryable`, `provider_error_non_retryable` and `provider_partial_stream_then_error`
have **scripted delivery for the first time** — before B2b, `stub_step`'s world provider wrapped every
entry in `Ok(…)` and those classes had none. C2 can assert more than the plan's sentence supposes.

**Unfavourably, and this one is a trap.** The whole tree drives acceptance scripts with `--ai-stub`
(`Makefile:270` and ~9 others), and the same docstring says:

> For providers **without native streaming**, the callback fires **exactly twice**: once with
> `ContentDelta(full_text)` then once with `Usage(...)`.

**If `--ai-stub` is such a provider, C2's "exact returned-log parity" is proven on a two-chunk stream**
— and ordering, duplication, and partial-stream-then-error are barely exercised or not at all. A
2-chunk pass looks identical to a real one in the output. **Measure the stub's chunk count before
designing the probe**, and if it is two, say so and get the ordering and duplication clauses from a
constructed multi-chunk source instead. A gate that is weak for a reason you named is worth more than
one that is strong-looking and unmeasured.

## Seven prose records go false the moment C1 lands, and none of them will go red

Same class as B4's four artifacts, and B4's lesson was that the dangerous ones are prose inside
versioned artifacts that gate nothing. **All seven gate nothing.**

| Site | What it says today |
|---|---|
| `src/core/ports.ail:352` | "Every construction site returns `emissions: []` today, so this widening is behaviour-preserving" |
| `src/core/session.ail:2071` | "`live_ports` returns `[]` until the recorded-stream API lands" |
| `src/core/dst_invariants.ail:78` | "`[]` on every path today … until the recorded-stream API lands, Milestone B" |
| `src/core/dst_invariants.ail:635` | "**Externally blocked**, not deferred by choice" |
| `src/core/dst_corpus.ail:986` | "the PARITY half is not observable. **EXTERNALLY BLOCKED**" |
| `src/core/dst_fault_catalogue.ail:333` | "no run can currently produce a non-empty emission log" |
| `scripts/dst/corpus_pr_dst.ail:82` | "until Milestone B. **Externally blocked**" |

Three of them say *externally blocked*, which is a claim about the world that **stopped being true on
the day v0.33.0 shipped** — before this item starts. Rewrite them to say what is actually true after
C1, which is narrower than "unblocked": the log is *produced* but has no driver consumer until the
parity invariant consumes it. **Do not upgrade a blocked record straight to a covered one.**

## Definition of done

**C1: the adoption, with the error path carrying its chunks** — and the `Err` branch's chunk
preservation asserted somewhere that fails if it regresses, not merely written correctly once.

**C2: the direct positive probe, all five clauses of `ADR:576-578` answered individually** —
immediate projection, exact returned-log parity, success, partial-stream-then-error, no duplicate
delivery. **Five rows, five answers.** A conjunction that passes tells you nothing about which clause
held, and per cluster 12's rule a row should assert its own fact.

**The forbidden fallback must be visibly not-selected.** D1 rejects delayed projection outright.
Immediate projection is the clause a stub is *least* able to prove, so state how you established it
rather than asserting it.

**All seven prose records corrected**, with the distinction above preserved.

**Per S13 — sweep the whole tree before believing a gate.** `check_core` is a SUBSET gate; it was
green while eleven files were broken, twice. Run the sweep cache-cold and report `make dst`'s exit
status with each remaining red target attributed to a class.

**Per S9 — clear EVERY live `.ailang/cache`, with both exclusions.** They are per-directory. An
unguarded sweep deletes `tools/code-graph`'s tracked test fixtures.

## Out of scope

- **WI-C3** (the streaming-trace parity invariant, D6.4's named exception) — it consumes what C1
  produces, and it is the item that finally gives the emission log a driver-side reader. Deliberately
  next, not now.
- **WI-C4**, the name gate. **Do not adopt the "DST"/"simulation" name on any target**, however well
  C2 goes. D10 gates the name on the full acceptance table, and B4 established that `driver_only`
  covers nothing *provably* — no extension is installable under D5 while `on_budget_plan` carries the
  ABI's closed `! {Env, FS}` row.
- **WI-C5** — `proc_exec`/`env_get` widening and the declared-versus-performed detector.
- The `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; `.gitignore:54`; the two v0.33.0-fixed workarounds.

## Stop and report rather than deciding inline

- **If `--ai-stub` cannot produce a multi-chunk stream**, C2's evidence is weaker than D1 asks for.
  Report it as a substrate limit and say which clauses are genuinely proven — do not let a two-chunk
  pass stand as the gate.
- **If immediate projection cannot be distinguished from delayed projection by any available
  observation**, that is a D1-level finding: the ADR rejects delayed projection, and a gate that
  cannot tell them apart does not enforce the rejection.
- **If adopting the recorded API changes `live_ports`'s declared effect row**, stop and read B4's
  refutation first — a wider function row does not type-check harmlessly, it **propagates** to every
  caller above it.

## Report back

Twenty-first calibration run, and the first of Milestone C.

- **The git wall-clock window.**
- **Each of D1's five clauses, answered separately**, with the observation that settled it. This is
  the item's durable output and it is the evidence D1 has been waiting for since the ADR was drafted.
- **The stub's measured chunk count**, and what it does and does not let C2 prove.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **39 across
  twenty runs; determinism has caught none** — and B4 refuted the structural argument that excused
  123 sites from ever being counted, so treat the closed-row population as in scope again.
- **Whether the emission log now has a consumer.** It does not, at the end of this item. Say so
  plainly rather than letting C2's green read as parity coverage — that sentence is C3's to change.
