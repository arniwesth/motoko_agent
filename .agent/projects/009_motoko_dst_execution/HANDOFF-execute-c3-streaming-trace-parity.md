# Handoff: execute WI-C3 — the streaming-trace parity invariant, and the bridge it turns out to need

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-C1 + C2 landed 2026-08-05** (~57 min): `live_ports` adopts `stepWithStreamRecorded`, and
`make recorded_stream` answers D1's five clauses in 23 rows across two subjects and two outcomes.
`make dst` exits 2 with exactly two red targets (`test_coverage`, `test_coverage_selftest`),
unchanged from B4 and neither in this item's class. **Confirm the tree state with `git status`
rather than believing any sentence in this handoff** — six handoffs have restated it and most were
wrong.

**Read first:** `NOTE-c1-c2-execution-report-and-plan-corrections.md`, then the plan's
`## Standing rules` — **S14 and S15 are new**, and **S14 is the rule this item exists downstream of.**

## Mission

**Give the emission log a reader, and make D6.4's parity obligation hold on a run rather than on a
fixture.**

C1 made `live_ports` produce a real ordered chunk log. C2 proved it. **Nothing reads it**, and
`session.ail:2071-2078` says so at the site. This item closes that.

## The finding that resizes the item — read this before planning

The plan calls C3 "the streaming-trace parity invariant … depends on C2 and A8", which reads like
*build an invariant*. **The invariant already exists and is already good.**
`dst_invariants.stream_parity_findings` (`:803`) checks count and order separately, keys on
`variant_id|ledger_event_key` so content drift is caught, and `invariants_dst.ail:698-710` already
proves it red against omission, duplication and reordering mutants.

**What does not exist is a bridge from a run to an `ExecutionUnderTest`.** Measured at HEAD:

| Question | Answer |
|---|---|
| Construction sites of `ExecutionUnderTest` in the whole tree | **One** — `scripts/dst/invariants_dst.ail:326`, a hand-authored `fixture()`, with `emissions: []` |
| Modules importing `src/core/dst_invariants` | **Three** — `invariants_dst.ail`, `run_report_dst.ail`, and `dst_run_report.ail`, which imports only `Violation, violation_rule, violation_family, family_id` |
| Seeded runners (`compaction_seeded_dst.ail`, `phase_c_seeded_dst.ail`) | import it **not at all** |

**So it is not merely the emission log that has no real-run consumer — the entire D7 invariant suite
has none.** All sixteen families run against one constructed fixture and its mutants. That is a
legitimate way to test the *checker*, and `dst_invariants.ail:78-86` says as much in its own header;
it is not a way to check a *run*. **Until the bridge exists, populating `emissions` reads identically
to not populating it** — which is this project's recurring failure mode arriving one level up.

**Decide the scope explicitly and say so in the report.** Either C3 builds the bridge and parity is
the first family to ride it, or C3 populates the channel and parity remains fixture-only, in which
case **the item does not discharge D6.4 and C4's acceptance row must not be marked from it.** The
first is the honest reading of the plan's intent. Do not let a green `make dst` decide it silently.

## The rule you will break by accident

**`Usage` chunks are returned but NOT projected, so the naive witness is off by one on every real
run.** `session.ail:955-975`:

```ailang
    ContentDelta(text)  => ledger_emit(… StreamDelta({ …, kind: "thinking",  text })),
    ThinkingDelta(text) => ledger_emit(… StreamDelta({ …, kind: "reasoning", text })),
    Usage(_) => ()
```

The returned log from `stepWithStreamRecorded` contains **every** observed chunk — C1's whole point,
and `--ai-stub`'s two chunks are `ContentDelta` **plus `Usage`**. The trace contains only the deltas.
A witness built as *map every chunk to a `StreamDelta`* yields **N+1 against N** and
`stream_parity_findings` reports `StreamParityCount` on every single run.

**And the tempting repair is the fail-open one this project keeps catching.** Faced with a red count,
the two-line fixes are `if emissions == [] then [] else …` and loosening count to a subset test.
Both make the invariant vacuous, both are green, and both look like a fix. **The correct repair is
that the witness applies the same filter and the same `kind` mapping as the projection** — which
means extracting the pure `StreamChunk -> Option[LedgerEvent]` core out of `append_stream_delta` and
using it on both sides, rather than writing a second converter. Two converters is two notions of one
quantity, which is the drift `ExecutionUnderTest`'s own comment (`:528-533`) warns about.

## The tautology boundary, and it is what makes the invariant worth having

Parity is only meaningful if its two sides come from **different places**:

- **Witness** ← `exchange.emissions`, the log the *provider returned*.
- **Trace** ← the returned `LedgerTrace.records`, filtered to `StreamDelta` by `stream_records`
  (`:849`) — what the *callback actually emitted*.

That comparison genuinely tests *every returned chunk was projected, once, in order*. **It is vacuous
the moment both sides derive from one of them.** The tempting shortcut exists because `ledger_emit`
is `-> () ! {IO, Trace}` and keeps no in-memory log, so there is no witness lying around — and the
callback cannot accumulate one, since its row is closed `{IO, Trace}` and D1 prohibits hidden mutable
port state. **`SharedMem` is not the escape hatch**; D1 rejected the scoped recorder explicitly and
selecting it needs an amendment, not a workaround.

Note what parity does *not* test: whether the mapping itself is right. Both sides use it. **That is
A8's vocabulary contract, not D6.4's**, and the split is correct — say it rather than letting parity
appear to cover it.

## Turning it on makes seeded runs RED, and that is the design working

The two scripted sites `stub_step.ail:225` and `:296` call `play_chunks` and then return
`emissions: []`. On a seeded run the trace will hold N `StreamDelta` records and the witness will
hold none, so `stream_parity_findings` yields `StreamParityCount(0, N)` — **loudly, per S2**. That is
the deterministic half of D1's parity claim announcing itself, not a defect in the invariant.
**Populate those two sites; do not skip the check when the witness is empty.**

## Definition of done

**The scope decision, stated** — bridge built, or channel populated and D6.4 explicitly not
discharged. **C4's acceptance row is only claimable under the first.**

**One converter, used by both the projection and the witness**, with `Usage`'s exclusion and the
`thinking`/`reasoning` `kind` selection living in exactly one place.

**The two scripted `play_chunks` sites populated**, so a seeded run produces a non-empty witness.

**The invariant proven red against a real mutant, not a constructed one.** `invariants_dst.ail`
already kills omission, duplication and reordering on fixtures; the new evidence is a mutant in the
*production* path — drop a chunk in the callback, or return the log with one element removed — and
per **S14** the gate must drive our own closure, not a fixture that resembles it.

**Per S13 — sweep the whole tree before believing a gate**, cache-cold, and report `make dst`'s exit
status with each red target attributed. **Per S9 — clear EVERY live `.ailang/cache`**, with both
exclusions.

**Per S15 — if a line-number anchor moves, its references in PROSE need tense**, not a global `sed`.
C1 falsified two historical notes this way and nothing went red.

## Out of scope

- **WI-C4, the name gate.** **No target adopts the "DST"/"simulation" name**, however well this goes.
  D10 gates the name on the full acceptance table, and B4's argument stands: no extension is
  installable under D5 while `on_budget_plan` carries the ABI's closed `! {Env, FS}` row, so
  `driver_only` still covers nothing *provably*.
- **WI-C5** — `proc_exec`/`env_get` widening and the declared-versus-performed detector.
- **The other fifteen invariant families.** If you build the bridge, parity is the first family to
  ride it; wiring the rest is a separate item with its own red surface.
- The `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.

## Stop and report rather than deciding inline

- **If the bridge cannot be built without the driver returning a trace it does not currently return**,
  that is a D6-level finding about what `DstResult` carries, not a detail to absorb. `session.ail:1101`
  is the only place a `result`/`trace`/`world` triple is assembled today — start there and report what
  it is missing.
- **If parity is red for a reason that is neither `Usage` nor the empty scripted witness**, report the
  sequence before repairing it. A real disagreement between the returned log and the trace is the
  defect D6.4 exists to find, and it would be the first one this project has caught on a live path.
- **If making the witness available requires widening the callback's effect row**, stop — that is the
  closed `{IO}` row D1's whole streaming disposition rests on, and B4's refutation applies: a wider
  function row propagates to every caller above it.

## Report back

Twenty-second calibration run.

- **The git wall-clock window.**
- **The scope decision** — bridge or channel — and whether D6.4 is discharged. This is the item's
  durable output, and C4 reads it directly.
- **Whether the invariant ran on a real seeded run**, and what it said the first time it did.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **45 across
  twenty-one runs** — the base is 43 from B4's report plus C1's two, correcting the 39 my C1 handoff
  carried. **Determinism has caught none**, and C1 is the first item where a purpose-built gate caught
  one.
- **Whether the D7 suite still has one construction site.** If it still does at the end of this item,
  say so plainly — it is the sentence C4 most needs and the one a green `make dst` will hide.
