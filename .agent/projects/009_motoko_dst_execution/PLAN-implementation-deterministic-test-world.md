# Plan: implementing ADR-001 — the deterministic test-world migration

Status: Proposed. Date: 2026-08-02.
Basis: `ADR-001-deterministic-test-world-architecture.md` (Accepted 2026-08-02) and the project-007
taxonomy ADR (Accepted 2026-07-26). Source ground: HEAD `eabaac8`, pinned AILANG v0.26.0.
Mandated by: the ADR's `## Implementation handoff` and `HANDOFF-implementation-plan.md`.

**This is a build order, not a second specification.** The ADR names every mechanism and states
every acceptance criterion; this plan sequences building them and says what evidence discharges
each. Per `measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`, no
work item below refines *how* a detector decides anything — where that question arises during
execution, the answer is a spike against the artifact, not a paragraph in this document.

## Review disposition

Two independent reviews, 2026-08-02: `REVIEW-implementation-plan-execution-safety.md` (10 findings,
*Accept with conditions*) and `REVIEW-implementation-plan-second-verification.md` (14 findings,
*Revise*). Their union is **14 distinct findings; all 14 are accepted and applied here**, and none
reopens D1–D11.

Both reviewers built probes on the pin and both **broke P2's stated ground** — independently, by
different routes — which is recorded in P2 below rather than quietly repaired. One reviewer's probe
also produced a *positive* result that **replaces P1's weaker M1 citation** with build-backed
evidence. Both confirmed, against source: P1's record choice, P4's vacuity, that **WI-A9 does not
need WI-A8** (the author's judgement, upheld), the `32 provider:` figure's honest use, and the
A1 → A2 → A12 spine with no cycles.

The findings cluster in one place, and it is the place the review handoff predicted: **ADR
obligations with no implementation home** — nine of the fourteen. Self-review had found two such
gaps and scheduled them; independent review found nine more. That asymmetry is the argument for
independent review of a completeness claim, and it is why this pass adds a work item (A15) rather
than only editing prose.

## Survey: executed at HEAD, 2026-08-02

The ADR's handoff requires ten re-verifications. All ten were run against HEAD `eabaac8` on the
pinned toolchain before this plan was written, per `re-ground-inherited-anchors-before-building.md`.

One structural fact makes the whole survey strong: **`git diff --stat a0d4edb..HEAD -- src packages
scripts Makefile .github tools` is empty.** Every source measurement the two acceptance reviewers
verified at `a0d4edb` holds at HEAD by construction. The independent re-measurements below all
agree; zero anchor corrections were needed.

| # | Survey item | Measured at HEAD |
|---|---|---|
| 1 | D1 streaming capture & upstream API | No released AILANG through v0.31.0 exports a recorded-stream API. `sunholo-data/ailang#546` is parked on drain semantics only; the `{chunks, outcome}` shape survived two quorum rounds and can be typed against now. Gate not cleared; the fork prototype clears nothing. |
| 2 | `Ports`/`StepProvider` constructions and consumers | `Ports` has 6 fields (`ports.ail:17-24`). All construction funnels through `ports_shape_probe` (`ports.ail:36`); callers: `live_ports` (`stub_step.ail:148`), `scripted_ports_from_steps` (`stub_step.ail:157`), and `scripts/dst/long_qwen_compaction_dst.ail` (3 sites, plus 3 record rebuilds at `:181`, `:252`, `:750`). Post-`89a1d67`, `C2LoopState.provider` is `Ports`-typed (`session.ail:344`), `dispatch_step` takes `Ports` directly with no dead branches (`stub_step.ail:192-200`), and `ported_provider` (`session.ail:695`) returns bare `Ports` from 6 call sites (`:2015`, `:2051`, `:2114`, `:2137`, `:2267`, `:2295`). `StepProvider` survives as the entry-point argument type only. 32 `provider:` occurrences in `session.ail` (loop-state literals plus entry-point signatures) bound the widening's edit surface. |
| 3 | World-state threading feasibility | Spike Q1 confirmed against the real driver (`NOTE-spike-findings-real-driver-vertical.md`); `C2LoopState` (`session.ail:338-357`) is an 18-field record threaded by one loop. |
| 4 | Direct ambient effects reachable in a session | Classifier 1 re-run at HEAD: union 25 modules, 21 imported, 13 effect-bearing, 8 proven effect-free, **0 unresolved**; `make effect_inventory_selftest` → `agree=43 disagree=0`. Clock: **13 `now()` sites** — 4 driver (`session.ail:791,842,1991,2089`), 1 `ext/runtime.ail:190`, 8 `motoko-ext-compose`. `readLine`: 2 sites (`session.ail:1619` approval, `:2196` conversation loop). `std/sem` `SharedMem` read at `rpc.ail:200`. **Nothing routed**; `ExtPorts.clock_now` has **zero call sites** (`grep -rn '\.clock_now('` is empty). |
| 5 | Tool/timeout contracts | `tool_exec` is stringly (`ports.ail:22`). Timeouts ride in requests — `timeout_secs` in `tool_catalog.ail:53` schema and `env_client.ail:31 exec_in` — enforced outside the AILANG driver. No in-profile module observes time; D4's first time-bearing seam (typed `ToolCallEnvelope` + deadline) is a contract to build. |
| 6 | Hooks in the baseline profile | Eight closed ABI slots (`motoko-ext-abi/types.ail:151-165`): three rowless, `on_budget_plan` at `{Env, FS}`, four at the nine-effect row; six dispatched by unconditional fold, only `on_tool_handle` gated. `.ai_step(` call sites: exactly **2** (`compaction_ai.ail:106`, `reject_fixtures.ail:90`). The baseline profile below installs no extensions, so its profile-reachable hook set is empty. |
| 7 | Traced-driver returns | All terminal summaries route through `emit_run_summary` (`session.ail:833`; call sites `1325` [shared error helper], `1554`, `1704`, `1711`, `1762`), whose only ledger operation is the `ledger_emit` projection. **Zero `RunSummary` in the returned trace on every path** — D6.1's starting count confirmed. `session.ail`: 37 `ledger_emit` vs 15 `ledger_append`. |
| 8 | Event vocabulary & consumers | `LedgerEvent` has **34 variants** (`phase_vocab.ail:597`); `ledger_record_name` (`phase_vocab.ail:561`) names 3 and collapses 31 to `"wire"`; wire names live in trailing comments; the consumer is a TypeScript `switch` in another process. Terminal reasons are integer codes through `finish_reason_str(r: int)` (`session.ail:820`) — the helper D6.2 requires replaced. |
| 9 | Seeded families & CI | `make dst` aggregates `compaction_dst conformance phase_c_l1 smoke_parity dst_l2 dst_seeded`; `dst_seeded` runs two seeded **scalar** families under `--caps IO,Env,Rand`. The only workflow is `verify-extensions.yml`. No generated-trajectory axis exists; nothing currently claims the DST name. |
| 10 | Exhaustive matches & configs | `match provider` at `session.ail:696` and `scripted_ports.ail:31` are the only `StepProvider` matches left. 14 checked-in configs, **all 14** installing `compaction_ai`; `compose` only in `.motoko/config/ailang`; `test_dummy` in none; `motoko_ext_conformance` absent from `registry_generated.ail`. Latent under-declarations confirmed present: `agents_md.ail:106 walk_agents` performs `FS` rowless; `a2a.ail:131` calls `uuid4()` under a row without `Rand`. |

Executable checks run for this survey: `make effect_inventory` and `effect_inventory_selftest`
(clean, above), and `scripts/dst/spike_scripted_cursor_probe.ail` against HEAD (renamed to
`scripted_cursor_probe.ail` when WI-A2 promoted it) — **F6 reproduces
exactly**: `folding: served=[s0,s1,s2,s2,…] advancing=false`, `FAIL`, `exit(1)`. The probe is the
executable statement of the first defect this plan fixes.

## Standing rules, earned by execution

These began as per-item clauses and are promoted here because repeated calibration runs confirmed
each of them. They bind every remaining item. **Grouped behaviour-first (S1–S3, S7–S8) then sizing
(S4–S6); the numbering is chronological, so it is not sequential in this order** — references in the
cluster reports are by number, so they are not renumbered.

**A REPRO CITED AS EVIDENCE IS A CLAIM ABOUT WHAT WAS MINIMISED AWAY, and it must be re-run against
the production type before it is cited a second time.** Earned by WI-D9. The ADR's four-line
record-field repro minimised away **the import**, which is the variable that decides the answer. It
was recorded at ADR time, cited at B4, and not run again for eleven items — during which D8 built a
finding on it and this reviewer built a handoff on it. **A minimal repro is minimal with respect to a
question; cited for a different question it is an untested assumption wearing evidence's clothes.**

**S1. Land the executable assertion *before* the change it guards, and make it cover advancement
*and* completeness — never determinism alone.** Clusters 1, 4 and 6 produced ten sites where both
alternatives type-check and the wrong one is silent. The compiler forces the *edit*; it does not
force the *right* edit. Determinism caught none of the ten; advancement caught the frozen cursors,
completeness caught the dropped records, and provenance caught the un-routed read. A12's clock
defect is the sharpest case: type-checks clean, trace-complete, **both determinism axes green**, and
wrong — visible only as `duration_ms: -1` and only to a check that the cursor moved.

**S2. Prefer the un-routed option that fails loudly over the one that fails silently.** Where a seam
cannot be routed on this pin, bind it so a future caller trips a gate rather than serving a stale
value. `ExtPorts.clock_now` cannot be bridged at all (zero-argument port, no zero-arg lambdas in
expression position), and the two available options were a frozen snapshot — silently wrong, cluster
1's pinned cursor exactly, invisible to every gate — or an ambient read that turns the `Clock` poison
probe red the moment anyone calls it. The ambient read is chosen deliberately. Same judgement as
WI-A16's, and stated once here rather than re-derived per seam.

**S3. Route the cheap instance of a seam before the awkward one.** A12's order put the clock second;
it overran, and every minute was `clock_now` being the only zero-argument port. `ExtPorts.env_get` is
two-argument and routed its extension seam in one line. Identical nominal scope, opposite outcome,
sole difference parameter count — had env run first, the limitation would have surfaced on the cheap
class.

**S7. A rejecting artifact needs a fixture that must SURVIVE, and that fixture must contain every
shape the specification explicitly protects — with no two of its quantities equal.** Mutation testing
(C5) proves a guard *can* fire; it cannot see a guard that fires **too much**, because every mutant
still produces its own rule. Only a fixture that must pass can. Three demonstrations:

- **A13 stage 1 (site 15).** D2 says reject "duplicate interaction identities" and, two paragraphs
  later, that the ordinal keeps repeated production call ids representable. Both readings type-check;
  rejecting the identity *body* makes a production retry undecodable. It passed all 18 mutant rows,
  was perfectly deterministic and trace-complete, and showed up **only** as a valid program being
  rejected — visible because the base fixture deliberately carries interactions #1 and #8 with a
  byte-identical tool identity at different ordinals.
- **A13 stage 2 (site 18).** The assertion built to catch over-recording was itself **over-rejecting**:
  the approval witness counted answers *consumed* where it needed reads *performed*.
- **The sharpening, and it is the mechanism.** Both were invisible to the `approve` and `deny`
  scenarios for the same structural reason — each queues exactly as many approvals as it consumes, so
  the two quantities are equal and any confusion between them is hidden. The `eof` scenario makes
  `tool_dispatches=1`, `approval_reads=3`, `approvals_consumed=1` pairwise distinct, and that is the
  whole mechanism. **A fixture whose quantities are all equal cannot distinguish which quantity a
  check is reading.**

**A14's refinement, and it is about the SHAPE of the fixture rather than about asserting it: S7 asks
for TWO different things and conflating them bloats the fixture for nothing.** "Every shape the
specification protects is PRESENT" and "no two QUANTITIES are equal" are separate obligations.
`invariants_dst`'s surviving fixture names the eleven quantities in its distinctness set — the counts
that at least two checks read and could therefore confuse — and deliberately leaves out the four
singleton interaction classes (env read, clock advance, random draw, extension effect), which appear
once each purely for shape coverage and whose counts no check compares to anything. Making those
distinct too would have meant sixteen environment reads in a fixture that needs one. **Name the
distinctness set; do not infer it from the numbers.**

**Assert both obligations executably; do not merely satisfy them.** Stage 3 promoted this after its
first `rich` fixture documented a tool-fault case it never reached — the queue held two entries
against one approved dispatch, so the header claimed a shape the run did not contain. The fix is not
a better comment: the suite now carries `the surviving fixture carries every shape the specification
protects` and `no two of the surviving fixture's quantities are equal` as **checks that go red**.
Prose cannot do this, because **a fixture's coverage drifts silently as the driver changes and the
author is the last person who will notice.**

Corollary, cheap and three times useful: **a fixture's stated justification is itself a claim, and it
is cheap to test.** Stage 2's `deny` scenario documented a purpose it did not serve; stage 3's `rich`
did the same. Introducing the mutation showed the real one, both times.

**The record-level form: a codec's guard is a round trip asserted field by field, with every field
holding a distinct value.** (The defect that earned this rule is written up in
`.agent/issues/ailang-no-warning-for-unreachable-match-arm.md`, with its reproduction and the
guidance that applies until a diagnostic exists upstream.) A codec's failure mode is a field the encoder writes and the decoder
ignores — both halves type-check and the loss is silent until a replay serves a different response
while every count still balances. This is S7's no-two-equal rule applied to a record instead of a
fixture, and it is what caught stage 3's `None`-binds-as-a-variable defect (three of four round-trip
rows red on first run) when `ailang check` and every count in the suite saw nothing. **A14/A15 will
encode programs for D8's persistence and inherit this directly.**

**Sharpened by A13 stage 3: ASSERT the fixture's coverage, do not describe it.** The corollary
above recurred within one cluster of being written. Stage 3's surviving fixture documented a tool
FAULT outcome it never reached — its queue held two entries against one approved dispatch, so the
fault entry was never consumed and the header claimed a shape the run did not contain. Prose cannot
notice that; the fixture's coverage drifts silently as the driver changes, and the author is the
last person who will see it. Both halves of S7 are therefore executable checks in
`strict_replay_dst`: *the surviving fixture carries every shape the specification protects*, and
*no two of its quantities are equal*. Either fails loudly when a future edit collapses it.

**And the same rule applied to a RECORD rather than a fixture: a codec's guard is a round trip
asserted field by field, with every field holding a distinct value.** A codec's failure mode is a
field the encoder writes and the decoder ignores; both halves type-check and the loss is silent
until a replay serves a different response while every count still balances. A14 and A15 encode
programs for D8's persistence and inherit this directly.

**TWO FURTHER EXTENSIONS FROM WI-D6, and the second changes what this project should reach for
first.**

**A producer's blind spot is a property of the QUESTION, not of the instrument.** C5's detector is
sound and its capability trap is the right producer for the question C5 asked about one hook. Pointed
at fifteen extensions it can answer for **seven** — because AILANG's capabilities are per-process, so
a registration that performs `Env` cannot be granted it while the dispatch is denied it, and nine of
fifteen `register_with_config` implementations read `Env` before any hook is dispatched. **No arm can
be written around that.** The fix was not a better arm but a *third producer*. **Before extending an
instrument to a larger subject set, ask what fraction of the new set its producer can reach, and
report the fraction rather than the subset.**

**And the compiler is an UNDERUSED producer here, which narrowing a row unlocks.** Every
declared-versus-performed argument since D5 assumed the declaration was fixed and therefore needed a
runtime witness. **The moment the declaration is a variable, the effect checker answers the same
question TOTALLY** — 15 of 15 over all inputs, where the trap witnesses 7 over the paths its arms
exercise. Verified at review: after the narrowing, a budget hook that reads `Env` is **rejected**
(`incompatible closed rows: r1 has extra labels [Env], r2 has extra labels []`), so a performing body
is not merely absent but *unwritable*. **`on_response_intercept`, `on_solver_candidate` and
`on_pre_step` are the three slots D5 still refuses on declared rows, and the same move is available to
each** — each with its own measurement, none of which has been taken.

**S15. A global `sed` over a line-number reference is safe for DATA and unsafe for PROSE, because
prose has tense.** Earned by WI-C1. Its anchor cascade rewrote `stub_step.ail:163` → `:182`
everywhere, correctly in every `site_key`, and **wrongly inside two notes that are records of PAST
state** — `driver_only`'s v3 note about what WI-A13 stage 4 did not disturb, and `ports.ail`'s
technique note. Both values are well-formed, both read like the same kind of fact, and after the
rewrite one of each pair was a **false claim about history**. Nothing goes red; it was caught by
reading the diff. **This is S12's shape in a new file class** — a live claim and a historical record
are indistinguishable by inspection — and it is the second time in two items that the dangerous
artifact was prose nothing checks. When a mechanical edit crosses into commentary, the anchor
reference needs a tense: say *"was `:163` at WI-A13, is `:182` now"* rather than letting a bare
number silently re-date itself.

**EXTENDED BY WI-C4, AND THE EXTENSION IS THE EXPENSIVE HALF: a stale number in prose gets QUOTED
FORWARD into a handoff and read as measurement.** Three stale instances this item
(`dst_event_vocabulary:808`, `dst_invariants:600`, `:628`), and the C4 handoff pointed at the first
while asserting *"the assertion beside it is correct and derives the list; only the prose is stale."*
**That was exactly backwards.** The assertion was `== 14 && contains_str(…, "StreamDelta")`; WI-C3 had
flipped `StreamDelta` out of the gap, so **both conjuncts were false and the test had been RED for two
items** — reproduced at review by running the pre-C4 file: `12 passed, 1 failed`, exit 1. The prose was
merely agreeing with an assertion nobody had checked. **So the rule is not "prose goes stale while code
stays true"; it is that a number repeated in two places will be reconciled by whichever copy a reader
finds first, and a handoff that states which one is authoritative without running it launders a guess
into a fact.** Third consecutive item to carry this class.

**WI-D1 GIVES S15 ITS PRACTICAL FORM, and it is a rule about how to WRITE a record, not only how to
read one.** D1 found **seven** stale reasons where its handoff named five — the extra two were in
`dst_fault_catalogue`'s own coverage-gap register and in `dst_run_report`'s header — and all seven
carried the same clause, *"`ScriptedStep` has no error channel"*, false since B2b added the field.
**The discriminator is what the reason was written FROM.** Of the four unreachable-class entries, the
three that named a **structural cause** ("the type has no such field") were false within an item or
two of being written; the one that quoted a **measurement** ("the generator's `tool_args` are always
well-formed JSON — measured 0 of 260") was still true four items later. A structural claim goes stale
the moment someone adds the field and nothing tells the reason; a measurement stays honest because it
describes a run rather than a design. **So: when recording why something is unreachable, record the
measurement, not the diagnosis.** Fourth consecutive item to carry this class, and the first to say
how to stop carrying it.

**A STATUS COLUMN IS A LIVE CLAIM AND ROTS LIKE ONE — WI-D11 found the ADR's gate-mechanism table
wrong on THREE OF FIVE ROWS.** `ADR:2410-2412` record classifier 2, the site-to-hook attribution table
and coverage-floor validation as **"Deferred"**. **Verified at review: `make ext_call_inventory`,
`make attribution_table` and `make profile_coverage` all exit 0** — every one built, green, and in
`make dst`, and the same document describes each as built in its own amendment paragraphs. **The
governance act checked five COUNT sites and found two the handoff had missed; it did not check the
State column, and that is where the disagreement was.** The column is demonstrably live-maintained —
WI-D10 edited classifier 1's State cell and the reviewers revised it four days later — so a reader is
taught that it tracks HEAD, which makes three false rows **silent** rather than merely stale.

**AND WI-D10 ADDS THE REFUSAL CASE, WHICH IS THE HARDEST ONE TO GET RIGHT: adding a CORRECT offset to
a number that is ALREADY WRONG does not fix it — it makes it look freshly maintained.** The D10
handoff instructed that 77 live ADR citations be re-derived after the amendment shifted them.
**Measured before the edit, roughly one in seven ADR self-citations already pointed at a blank line or
a code fence** — the report counts 105 of 753 instances (13.9%); an independent re-derivation at
review counts **38 of 272 distinct citations (14.0%)**, which is the same rate by a different unit.
**So the instruction was wrong and the item was right to refuse it.** Offsetting them all would have
produced a document whose citations were uniformly *fresh* and still substantially *wrong*, in the one
medium where nothing can go red. **The decay was reported, priced and left owed instead**, and named
anchors were adopted for the two amended passages so the new text contributes zero numeric
self-citations. **The rule: before mechanically correcting a reference layer, measure how much of it
was already correct. If the answer is "most", correct it; if the answer is "unknown", correcting it
hides that.**

**WI-D2 SHARPENS IT AGAIN, and the failure is narrower than "structural reasons go stale".** Of
`parity_gap_reasons`' thirteen entries, **eleven named a structural cause and nine were wrong** — and
seven of those said *"inside the tool dispatch fold"*, which described **where the code lived**, not
what prevented the append. The obstacle was the fold's RETURN TYPE. A reason naming the location
cannot go red when the location is fine and the type is not. **So: a structural reason must name the
thing that would have to CHANGE, not the place the code lives.** The item also found four sites where
**the REASON expired and the CONCLUSION held** — three justified reading the wire instead of the trace
on the grounds that the trace did not carry the event, which is no longer true while the conclusion
still stands on independence of authorship. **Restate those in two parts rather than re-dating them**,
so the next reader can see which half is load-bearing.

**EXTENDED BY WI-D10, AND THIS IS THE FORM WHERE THE WHOLE LAYER IS ALREADY GONE.** Every prior
instance of S15 is about one stale number. WI-D10 was the first item to edit ADR-001's *body* rather
than append to it, so it had to re-derive the citations below the edit — and measured the layer first
rather than trusting it. **105 of the ADR's 753 internal line-number self-citations (13.9%) pointed
at a BLANK LINE or a CODE-FENCE MARKER *before* the edit**, 72 of them in the region the edit does
not touch at all; a hand-sample of fourteen more found roughly two that still matched their claim.
**The citation layer had already decayed document-wide from ordinary growth, and no item in
thirty-four had ever re-derived it.**

**So the re-derivation was deliberately NOT performed, and that is the rule: adding a correct offset
to an already-wrong number produces a wrong number that looks freshly maintained.** That is S15's C4
extension — *"launders a guess into a fact"* — in the one medium where it is invisible by
construction, because every rewritten citation is well-formed and nothing can go red. **Report the
decay, price the repair, and do not disguise it as a cascade.**

**THE DETECTOR IS CHEAP AND NOBODY HAD RUN IT: a citation whose target line is BLANK or a code fence
is definitely wrong**, needs no semantics, and covers a whole document in seconds. Run it before
believing any line-number citation — including the ones in a handoff. WI-D10's own handoff cited
`ADR:2113` for *"None of the three"*; that sentence was at `:2115`.

**AND THE CENSUS ERRED IN BOTH DIRECTIONS AT ONCE, because it did not know every citation FORM.**
The amendment review counted `ADR:NNN` and reported 76 self-citations below the insertion point.
There is a second form — a backticked bare `` `:NNN` `` — with **197** instances, so the census was
too small. **But most of that form is not an ADR citation at all:** it is a *file-relative
continuation* of the file named earlier in the same sentence (`session.ail:1770` … then `` `:1778` ``),
so counting them would have been too large. **Naming the form is not enough; the form's REFERENT has
to be derived too** — and a census that gets one of those wrong is wrong in a direction it cannot
detect from its own output.

**AND A NOTE THAT STATES A SHIFT, PLACED ABOVE THE REGION IT DESCRIBES, INVALIDATES ITS OWN NUMBERS.**
S18 says tensing a comment is a source edit for cascade purposes; this is that one level up, and it
bites twice because the correction is also an edit. WI-D10 wrote the shift as `+260`, added the note,
and the true shift became `+287`/`+305`. **Derive the map from the DIFF, never from the edit sizes,
and then patch only the digits so the line count does not move again.**

**FINALLY, FROM WI-D10's ONE MEASUREMENT: when a review proposes a fallback route, probe it AND
enumerate the alternatives, because the proposed route is the first one someone thought of rather
than the best one available.** The review argued classifier 3's symbol granularity was reachable by a
per-declaration textual parse, *"a small change"* to an existing tool. **Probed: it works** — 465
symbols over 46 modules, unclaimed-`export` residue 0, collapsing back to the shipped module
derivation 46 of 46. **And it fails OPEN on 44 of 465 symbols** — 39 `export func` carrying no row at
all and 5 effect-*polymorphic* (`std/list.mapE` and siblings) — which for a fail-closed instrument is
the wrong direction, and one of the 39 (`std/json.jo`) is imported by three of the four extensions the
instrument's whole yield rests on. **Two strictly better producers existed and nobody had looked:**
the compiler's own cached `iface.json` (`ailang.iface/v1`, per-symbol, typed, 23 of 46 modules — every
one this tree compiles), and `ailang iface`'s own stdout, which already emits `funcs[].effects` and is
blocked only by MOD010's path rule. **A tool's stated limitation is a claim about the tool, and this
project's record on those is why S22 exists.**

**S14. A direct probe of an upstream API is NOT evidence that OUR adoption of it works — the gate
must drive our own closure.** Earned by WI-C1, and **measured rather than argued**: the natural wrong
adoption of `stepWithStreamRecorded` (match on the outcome, `Err` arm drops the chunks) is green under
`ailang check`, green under `make check_core` at 52/52, green under `make driver_only`, and green on
**every substrate row of C2's own probe** — because the substrate rows never call `live_ports`. Only
the *adoption* rows, and only in partial-stream-then-error, go red. Anyone who builds only the direct
API probe — which is the most natural reading of D1's "a direct positive version of the spike" — ships
a green gate over a broken adoption. **Two subjects, not one**, wherever an item adopts an external
API. This generalises past streaming and binds C5.

**S16. A parity check whose two sides share a PRODUCER tests threading, not parity — and the
difference is the whole defect class.** Earned by WI-C3, and measured rather than argued. D6.4 says
the projected sequence and the returned emission log must match; in-process there is exactly ONE
observation of the stream (`ProviderExchange.emissions`), because the callback's projections go to
`ledger_emit`, which returns `()`, and the callback's row is closed `{IO}` so it cannot accumulate
what it saw. So the invariant's two sides both derive from the returned log. **A de-duplication
injected into the callback — the projection disagreeing with the returned log, which is literally the
defect D6.4 names — leaves `stream_parity_dst` COMPLETELY GREEN**, and is caught only by comparing the
WIRE (what the callback projected) against the returned trace (what the driver appended), which is out
of process and lives in `run_stream_parity_wire.sh`.

**Reproduced independently at review**, because a claim this load-bearing should not rest on one
run: a callback that drops one delta class leaves the in-process gate green with **0 findings**
across all sixteen families on the recording subject, while the wire gate goes red on three rows at
**`wire_deltas=10` against `trace_deltas=14`** — including the fixture-adequacy row that exists to
make de-duplication visible.

**SHARPENED BY WI-C5, AND IT EXTENDS TO THE INSTRUMENT'S OWN PLUMBING.** S16 as written governs the
two sides of the property. C5 built a detector whose two sides were genuinely independent — a static
ABI row against an out-of-process capability trap — and it was **green at nine of nine rows over an
arm whose dispatch had been DELETED**, because the *completion marker* was produced by the arm's own
code. The property's producers were right and the instrument's were not. **So: the value a check
asserts on must be one the subject can only produce BY DOING THE WORK.** C5's fix registers a witness
hook after the subject in the same unconditional fold, so the asserted sentinel is unobtainable
unless the fold ran and invoked the subject first.

**Independently reproduced at review, and the fix is stronger than the report claims.** Deleting
`compose_budget`'s dispatch and leaving its `reached(...)` marker behind reddens **two** rows, not one:
the witness row (`compose_budget exited 0 but its witness is not '4242' — the fold did not run past
compose, so this row measures nothing`, witness=100, the arm's own input) **and** an independent
structural row (`expected 6 mentions of compose_then_witness (1 definition + 5 arms), found 5`). The
second catches the same deletion by a different route, which is what makes the repair robust rather
than a patch over one mutant.

**And the limit C5 measured on its own fix, because it is the honest boundary:** a subject whose
binding is a CONSTANT NO-OP is unobservable in a dispatch result by definition. Removing the subject
from the registry entirely reddened only the ONE arm that names it by id. Three of four arms
therefore establish "the fold ran and performed nothing", not "the subject ran and performed
nothing", and the two are joined by a separate structural row rather than conflated.

**AND WI-D15 FOUND TWO MORE DOORS, one of them live in the SHIPPED tool.** **Door 3: a
NON-underscore language builtin.** `show` needs no import, is declared nowhere, and is not
`_`-prefixed — so classifier 3 *neither resolves nor rejects it; it does not look at it.* Verified at
review: **five `show(` calls in `compaction_structural.ail`**, none imported, none declared. That is
the extension `driver_plus_no_ops` rests on, and sixteen of its criterion-2 entries trace to
classifier 3 clearing it. Under the import-granular unit it costs nothing; **under any call-granular
unit it is the dominant term.** No producer at HEAD can classify it — every `show(` in the 46-module
stdlib corpus is inside a comment — and a textual derivation was tried and **discarded** because it
could not distinguish a language builtin from a higher-order parameter, resolving `f`, `p` and `pred`
as builtins. **A rule that invents evidence is worse than one that reports its absence.**

**Door 4: a call site inside a STRING INTERPOLATION**, which the noise-stripper blanked. Ten builtin
and two effectful std-symbol calls exist *only* there. Harmless to an import-granular verdict, and
invisible to any call-granular reader that inherits the same lid.

**AND WI-D12 ADDS THE DOOR AN INVENTORY DOES NOT WATCH: an instrument scoped to IMPORTS is blind to
effects that need no import.** AILANG's effects are performed by `_`-prefixed compiler builtins —
`std/io.println` is literally `_io_println(s)` — **and a builtin requires no import statement.** An
import-only ambient inventory sees none of them. **Not hypothetical, and verified at review:**
`packages/motoko-ext-compaction-structural/compaction_structural.ail:251` calls `_list_length(...)`
directly, and **nothing in that file's import list would flag it** — so an import-only classifier 3
would have cleared *the very extension it was built to clear* with an unaudited raw builtin in its
closure. Seven distinct builtins are called across the fifteen extension closures.

**The fix is the same producer, not a list:** a builtin is provably effect-free only when some
`std/*` export whose body calls it carries a **closed empty cached row**, because the effect checker
is transitive through direct builtin calls. **68 builtins are wrapped by an effect-bearing export;
all seven the tree uses resolve pure, so the yield is unchanged — but unchanged by measurement.**
**The general rule: enumerate the ways a subject can reach the thing you are scanning for, before
choosing the unit you scan.**

**AND WI-D11 FOUND THE RULE STATED CORRECTLY IN ONE FILE AND VIOLATED IN THE NEXT.**
`src/core/dst_attribution_table.ail:446-448` says, verbatim: *"The discovered set is an ARGUMENT,
never a constant in this module. It comes from an inventory run against the source, and **hardcoding
it here would make this check agree with itself by construction.**"* At the only live call,
`scripts/dst/attribution_table_dst.ail:133` passes `head_inventory()` — which is
`unconditional_core_sites()` **plus the two sites `attribution_rows()` already contains**
(`ext/runtime.ail:190`, `tool_phase.ail:314`). **Verified at review: the "discovered" set is the union
of the two lists `validate_completeness` checks membership against, so it cannot reject over them.**
The negative fixture proves the *rule* discriminates; nothing feeds the *instrument* a real inventory.
**A module that names its own failure mode in a header comment does not thereby avoid it** — the
comment and the call site are in different files, and nothing connects them. This is acceptance row
5's completeness guard.

**GENERALISED AT WI-D2 FROM A PROPERTY'S TWO SIDES TO AN ARTIFACT'S TWO PINS.** C3's form is about a
check whose two sides share a producer. D2's is about two SEPARATE artifacts pinned against each other
— `d64_gap_register` and the vocabulary's `reaches_trace_today` survey — which reads like redundancy
and is not. **Both are hand-written claims, and agreeing with each other is not evidence about the
code.** Measured: with the driver appending nothing from the tool fold, `make event_vocabulary` and
`make invariants` are **both exit 0** while the new wire gate reads `projected 1, returned 0`.
Reproduced independently at review, all three exit codes confirmed. **The register's two-sided pin is
not a check that the append exists; it is a check that two claims match.** So: **when a pin compares
two artifacts, ask which one an execution produced. If neither, the pin checks consistency, not
truth** — and the fix is to drive the requirement off the claim under test, as D2's gate does by
deriving its required set from `event_vocabulary()` minus the register, so *removing a name from the
register is what makes the gate demand its append.*

**EXTENDED AGAIN AT WI-D3 TO A CHECK'S COMPLEMENT, and this is the form with no shared producer at
all.** C3's version is a check whose two sides share a producer; D2's is two artifacts pinned against
each other. D3's poison pairs have neither problem — the AILANG interpreter kills the run, the exit
code is the whole observation, and nothing in this tree participates — **and they are still green over
a world the driver never reads.** Measured: bind the deterministic file seam to ignore
`WorldState.files` entirely and the Env- and FS-withheld deterministic runs produce **no capability
error at all**; they complete the session and fail only a separate provenance assertion. Reproduced
independently at review. **A poison pair is a statement about what a run does NOT read and is silent
on whether the world is read at all.** So: **a gate establishing what a run does not do says nothing
about what it does. Poison pairs and provenance assertions are complements, and closing a row on one
of them closes half of it.** C4 ruled that provenance is not hermeticity; D3 establishes the converse
just as strictly.

**A further C5 finding, for any future "did X perform effect E" check: prefer the ENFORCEMENT
mechanism over the RECORD.** The world interaction log looks like a second producer and is not one
for ambient effects — it records what was requested *through the world*, so absence from it is not
absence of the effect, and that fails OPEN in the direction that grants coverage credit. The
interpreter's capability trap cannot be silent.

**Two consequences, and the second is the transferable one.** First, an in-process check built this
way is still worth having — it tests that every branch carries both channels forward, which is S12's
identity-transition class on a pair of channels, and WI-C3's mutant A reddens 5 rows with it. Second,
and generalising past streaming: **before writing any "the projection matches the record" check, name
the two producers. If they are the same expression, say what the check actually tests at the site, and
build the second gate somewhere the other producer is observable.** This binds C5's
declared-versus-performed detector directly, which has exactly this shape.

**The corollary that resized WI-C3, and it is cheap to miss: a variant in `d64_gap_register` has NO
trace side at all.** `ledger_emit` does not call `ledger_append`. Before WI-C3 the emission witness was
`[]` because nothing read it AND the trace held zero `StreamDelta` records because nothing appended
them — **both sides empty, and two empty sides are green.** Any future item that reads "parity is
checked over the returned trace" for a registered variant is reading a comparison against an empty
list.

**EXTENDED BY WI-D4 TO A GATE'S OWN REPORTING PATH: check the ARTIFACT, not the TRANSCRIPT.**
`corpus_pr` writes its full output to `/tmp/corpus_pr.out` and, **on failure only**, prints
`grep -v '^{' … | tail -40` (`Makefile:1091`) — while on success it prints the whole file
(`:1092`). **A recipe that shows LESS on failure than on success has an inventory only on the happy
path.** The class-coverage rows scrolled off that 40-line window, and **two sessions in a row read the
make transcript and concluded the rows were absent** — this reviewer among them, having grepped a
captured `make` log rather than the artifact. They were not absent. They were **RED**, naming a
required fault class no bank member reached, which is a coverage regression rather than the
bookkeeping gap "missing" implies. **The correction matters in the direction that costs more:
"unevidenced" understates "failing".**

**A FOURTH MEDIUM, from WI-D6: a SWALLOWED EXIT CODE.** Reading `$?` after piping a script through
`tail` reported success over a run that exited 1. The four are now: an absent tick (C4), an absent
count (D1), a truncated artifact row (D4), and a discarded exit status (D6). **Every one is a signal
that was produced and then lost between the producer and the reader.**

**EXTENDED BY WI-D10, ONE LEVEL UP, AND IT IS THE PRETTIEST INSTANCE OF THIS RULE: a note that
STATES a line-number offset, placed above the region it describes, makes its own number wrong.**
WI-D10's line-number map first read `+260`; the note sits above the shifted region, so writing it
moved the very lines it was measuring, and the true offsets are `+287` and `+305`. **Well-formed,
plausible, and invisible to every gate** — caught only by re-deriving the map from the diff after the
fact. S18 says tensing a comment is a source edit for cascade purposes; **this says a comment ABOUT a
cascade is part of the cascade it describes.** Derive such a map from the diff, after the edit,
never from the intent before it.

**S18. Tensing a comment IS a source edit for anchor-cascade purposes.** Earned by WI-C5, which is
the SECOND consecutive item to pay the line-number cascade twice, both times for the same reason:
comment edits landed after the anchors were computed. C3's operational rule ("finish every source
edit, including comments, BEFORE running the cascade") is correct and was followed for the source
edits; what broke it was rewriting a historical comment block for tense under S15 *after* the anchor
numbers were derived, which moved four `session.ail` line numbers by nine. **S15 and the anchor rule
interact, and the interaction is the trap:** S15 tells you to go back and tense a comment, and doing
so re-dates every anchor below it. Do the tensing first.

**EXTENDED BY WI-D16 TO A PIN THAT ITERATES ITSELF, and it is the same defect one level above the
tool.** Classifier 2's membership self-test loops over `expected.json`'s pinned block, **so adding a
NEW `ExtPorts` field produced four green pinned rows and total silence on the fifth.** The `fixtures`
block already carried a `missing` check; membership had no counterpart. **A pin that enumerates from
itself cannot report an absence** — which is `derive.py`'s own documented fail-open shape, reappearing
in the harness that guards it. Closed with a **two-directional reachability assertion**, and both
directions mutation-tested: dropping `file_read` from the pin and pinning a `http_get` that does not
exist each produce a named failure.

**AND `make anchors` IS NECESSARY AND NOT SUFFICIENT — it checks the anchors, not the set of profiles
that recorded the table's hash.** WI-D16's widening pushed five `session.ail` anchors down;
`make anchors` and `make attribution_table` both went green with only `driver_only` re-issued, and the
**sweep then failed `driver_plus_no_ops`** — *"the attribution table was corrected and this profile was
not re-issued (D4)"*. **The second profile binds the same table at the same identity**, so the D4
cascade now has two consumers and the anchors target names one. **A third profile extends the list
again with nothing naming it in advance** — S22's derive-the-consumer-list rule, owed on this cascade.

**S26. AN ASSERTION THAT NAMES ITS SUBJECT POSITIONALLY CAN PASS WHILE READING THE WRONG SUBJECT —
so EXTEND a shared fixture by APPENDING, never by inserting.** Earned by WI-D17, and it is a failure
shape distinct from every other rule here.

The two new filesystem classes were first added to `invariants_dst`'s fixture at ordinals 15 and 16,
pushing the terminal provider from 15 to 17. Three checks in
`scenario_fixture_carries_every_protected_shape` name an interaction **by ordinal literal**, one of
them `total_chunks(log) == 8 && List.length(at_ord(log, 15).outcome.chunks) == 0`. **That row went on
printing `✓`** — `at_ord(log, 15)` was now a `file_write`, which also has no chunks. The insertion was
caught only because a *different* row (`count_status(log, "missing") == 1`) happened to break.

**This project's counted mode is "absent reads identically to unchanged". This is the other one:
PRESENT-BUT-WRONG reads identically to CORRECT.** A green row reading the wrong subject is worse than
a red one, because a red row is an invitation to look and a green row is a claim that nobody will
re-open. **An ordinal literal is a positional reference with no type behind it at all.** Fixed by
appending after the provider, so every ordinal literal in the file still points at what it was written
for.

**S25. A HANDOFF THAT PRESCRIBES PINNING A DISTINCTION MUST STATE THE DESIGN ASSUMPTION THE
DISTINCTION DEPENDS ON — otherwise it either pins a non-difference or pushes the item toward the
design that makes the difference real.** Earned by WI-D17, and it is the SECOND consecutive item whose
handoff framing led toward the wrong answer, which is what makes it a rule rather than a slip.

**D17's instance.** The handoff measured `lookup_file` as first-match and concluded: *"prepending gives
write-then-read-sees-the-write for free, and appending gives stale-read-wins — a one-token difference
with opposite semantics. Pin it."* **The item's mutants say it is conditional.** With the dedupe the
adapter actually carries (`remove_path` then prepend), append and prepend are **observationally
identical** — at most one entry per path, so position cannot matter to a lookup that matches on path.
Only *without* the dedupe does append produce the stale read. **The prescribed pin would have pinned a
distinction that does not exist under the chosen design.**

**D16's instance, the same shape one item earlier:** the handoff framed the write/print question as
*"a file write is not an observation"* — true, and the wrong question, because the write CAUSES an
observation.

**The rule: when a handoff states a consequence, state what it is conditional on.** Both errors were
unconditional statements of things true only under a design the item had not yet chosen — and in both
cases the item's own measurement defeated them, which is the process working and is not a reason to
keep making them.

**S24. A FIXTURE SUITE PROVES THE SHAPES IT ENUMERATES; IT DOES NOT PROVE THE WALKER REACHED THE
CODE.** Earned by WI-D15, which had **four** slips in its own tooling — and **two were FAIL-OPEN, and
the assertion suite caught neither.** Both were caught by a human reading a verdict that was better
than the source justified.

The sharper of the two: a brace-delimited **record type in a return signature** —
`-> Result[{ stdout: string, … }, string] ! {Process} {` — read as a function *body*, so `shell_exec`
looked effect-free and **`omnigraph` reported HOOK-PORT-MEDIATED while its `on_tool_handle` calls
`std/process.exec`.** A clean answer for an extension that shells out. Every fixture passed
throughout, because the fixtures enumerate *shapes a walker must reject* and none of them asserts
*that the walker arrived*.

**The rule: for any analysis that walks to reach its subject, assert reachability separately from
verdict.** A suite of rejecting fixtures with resolving controls — this project's standard since C5 —
establishes the predicate and says nothing about the traversal. **And the practical tell is the one
that worked twice here: a verdict better than the source justifies is worth reading by hand before it
is banked.**

**S23. A TRANSCRIBED CONSTANT BECOMES CHECKABLE THE MOMENT A SECOND CONSUMER HAS TO STATE IT — so
build the second consumer, or guard the first.** Earned by WI-D14, and it is the rule behind **the
first LIVE instance of this project's counted failure mode in thirty-eight runs.**

**`driver_only` and every manifest built for it pinned `abi_version` at `"4.0"`. The ABI package has
declared `5.0` since WI-B2b** — verified at review: `packages/motoko-ext-abi/ailang.toml` says
`version = "5.0"`, and the pre-D14 profile said `"4.0"`. **Both readings type-check**, because
`abi_version` is a free `string` field and a free argument to the manifest builder, **and the wrong
one was silent for eleven items** — in the one artifact whose entire stated purpose is exact
reproducibility. The manifest's own header says it "is a transcription by nature … so every field that
CAN be read back from an artifact is read back" and lists four rule versions as the composition
defect's natural home. **`abi_version` was a fifth and nobody had put it on the list.**

**What found it was not an instrument.** It was writing the SECOND profile's boundary note and having
to ask what number to put in it. **A constant that only one artifact states is a constant nothing
compares**; a second statement of it is a comparison whether or not anyone intends one.

**Now guarded, and the guard is total rather than pointed:** `check_abi_version` re-derives the
version from the package's own `ailang.toml` across both profiles' records, fixtures and inline tests
and **fails if it finds no site to check** — which caught a third stale site on its first aggregate
run, one the two hand-fixes had missed. Verified at review: *"the ABI version every profile record
names is the one the package declares: 5.0 (6 site(s) across 4 file(s))"*.

**S22. When an item's scope is "every X", DERIVE the list of X from a producer in the tree and assert
the agreement in the gate. Never take it from prose.** Earned by WI-D6, against its own handoff.
**The handoff named eight extensions binding `on_budget_plan`; there are fourteen besides compose.**
Verified at review: 17 packages reference the slot, of which 15 are binding extensions, and the six
the handoff missed — `mcp`, `context_mode`, `ailang_docs`, `decision_framework`,
`compaction_structural`, `empty_stop_guard` — are all in `registry_generated.ail`, the host's own
install set.

**Nothing turned on it, and that is luck rather than design.** All six bind the slot with a constant.
**But the same handoff argued that "a single binding that genuinely performs `Env` or `FS` blocks
Route A" — which makes the count load-bearing by its own reasoning.** An undercount of six in a
population where one member can refuse the whole change is a scope claim doing the work of a
measurement.

**This is S16's independence requirement applied to a work item's SCOPE rather than to a check's two
sides.** D6's answer is the general one: the gate now derives its subject list from
`registry_generated.ail` and asserts membership both ways, so **an extension added tomorrow cannot
escape measurement by not being noticed.**

**AND WI-D13 SHOWS THE UNIT CHANGING UNDER PROSE THAT WAS NEVER WRONG.** When a derivation acquires
a **finer** unit, every passage written while only the coarser unit existed becomes ambiguous at best.
`packages/motoko-ext-abi/types.ail` carries three passages asserting *"THE SLOT IS STILL A BARRIER"* —
**true of the slot, and read as a claim about all fifteen extensions because until WI-D13 there was no
other unit to read it in.** The moment `check_barrier_count` re-derived per `(extension, slot)`, four
extensions had zero barriers while every one of those sentences remained literally true. **Qualified
in place per S15 rather than rewritten**, comment-only, no ABI surface change. **The rule: adding a
unit to a derivation is a documentation cascade over everything that quantified in the old one**, and
unlike a stale number nothing about it looks stale.

**AND WI-D12 SHOWS THE QUANTIFIER'S UNIT CHANGING THE ANSWER: the ADR's own "1 of 15" for the
textual route is 0 of 15 under the ADR's own property 2.** The figure reasons over each extension's
**package sources** — *"`std/json.jo` carries no row and three of those four import it"*, which is
exactly right about the packages. **But the amendment's property 2 makes the unit the transitive
CLOSURE**, and `packages/motoko-ext-abi/types.ail:12` imports `std/json (Json, jo)` and is in **all
fifteen** closures — verified at review, `decision_framework`'s closure is two modules and one of them
is that file. So under the textual route all four are rejected, not three. **The correction
STRENGTHENS the criterion it appears in**: the clause exists to say the cheapest producer would have
destroyed the result, and under the criterion's own quantifier it destroys all of it.

**AND THE FALSIFIER MUST COVER HOW THE SET IS RESOLVED, NOT ONLY WHAT IT CONTAINS.** Found by the
amendment review, and it is the sharpest instance of this rule yet: `scratchpad`'s package directory
is `packages/motoko_scratchpad`, **not** `packages/motoko-ext-scratchpad`. **A derivation that
resolves package directories by naming convention silently resolves 14 of 15 — and 14 is exactly the
answer being claimed.** A wrong derivation and the right number, indistinguishable by inspection and
by the residue check. The mapping must be read from its producer, `ailang.toml:24`. **A falsifier that
counts members does not catch a resolver that lost one; it has to assert the resolution too.**

**EXTENDED BY WI-D7, ONE LEVEL UP AND AGAINST THE ITEM THAT EARNED THIS RULE: when an item's
conclusion is "X IS NOW UNBLOCKED", derive the list of things that BLOCK X from a producer and assert
the COUNT — not just the list of things you changed.** D6 derived its *subject* list from
`registry_generated.ail` and asserted the agreement, exactly as this rule requires, and then took its
*barrier* count from prose. **It was wrong by three.** `on_budget_plan` was one of four barriers;
`on_pre_step`, `on_response_intercept` and `on_solver_candidate` are all unconditionally dispatched
and none is coverable, so no extension was installable and none is now. **A scope claim and a
completeness claim are the same kind of claim**, and the checked one held while the unchecked one did
not.

**The disagreement reached SIX artifacts, two of them EXECUTABLE** — `check_fixtures.py` asserted
installability in `print()` and `hook_guard_dst.ail` in `println`, on every run since D6 — and they
could disagree indefinitely because **nothing computed the count.** D7's answer is the general one:
`make profile_definition` now derives it from the ABI rows and `dst_profile_coverage.hook_dispatch`,
prints each slot's status, and **goes red at zero** so reaching it is a decision rather than a side
effect of an ABI edit. Verified at review: it prints
`3 barrier(s) stand, so NO extension is installable in a conformant profile`.

**EXTENDED BY WI-D7, AND THE EXTENSION IS ABOUT THE ANSWER RATHER THAN THE QUESTION: a reported
concentration is a CLAIM about what a closure removed, so a closure that did not happen produces
concentrations that did not happen.** D6 applied S21 correctly — it asked each surviving exemption why
it survived — and answered *"the reason concentrated"* in three separate files, each locally
consistent. **All three were downstream of one wrong sentence**, and D7 withdrew them: row 3 still
rests on an install list no profile *can* fill, row 4's waiver still rests on two reasons rather than
one, and row 5's *"compose is now actionable"* was false because compose is not installable. A fifth
site outside the table (`dst_hook_guard`'s unreachability) went the same way. **So: when an item
reports a concentration, the reason it says was REMOVED must be checked as an artifact, not
asserted.** A concentration is falsifiable and nothing was falsifying these.

**EXTENDED BY WI-D13, AND IT IS THE HARDEST FORM TO REFUSE: a vacuity that arrives with a NUMBER
attached is harder to see than one that does not.** Classifier 3 clears four extensions, and D13
measured what their coverage would be worth: **two of criterion 2's three clauses hold because nothing
happens** — *"effectful only through world-mediated ports"* over an empty set of effects, and
*"origin tagged by extension id"* over nothing to tag. Amendment A predicted it in advance
(`ADR:1611`): *"the first hook classifier 3 clears will be one that performs nothing, not one that
mediates."*

**Installing them would produce a real, non-zero extension-model coverage number and exercise none of
the world-mediation machinery.** `driver_only`'s table already leans on an empty install list in four
places; this would be a fifth vacuity **and the first with a figure in front of it.** D13 declined and
recorded the reason as being about *evidence*, not correctness. **The rule: when a measurement first
makes a previously-blocked claim available, ask what the claim would be evidence OF before banking
it** — and a non-zero number is the worst possible moment to stop asking.

**S21. When a row closes, re-ask of every surviving exemption in every OTHER row why it survives — a
closure narrows the set of reasons, and a reason that used to be one of many can become the only
one.** Earned by WI-D5, and it is the only rule here about a defect that gets WORSE as the work gets
better. This project has tracked which acceptance rows pass vacuously since C4, carefully, row by row.
**The count still moved from two to four without any item noticing**, because each caveat was recorded
correctly inside its own row's prose and nothing ever counted them together.

The instance: at C4, `d64_gap_register` held thirteen variants of which **eleven were
`driver_only`-reachable**, so the profile's empty install list was irrelevant to row 7 — the row failed
for reasons that had nothing to do with extensions. **WI-D2 closed those eleven.** What remained was a
residue of two, and **one of them (`ScratchpadResult`) is unreachable precisely because no extension is
installed to emit it** — its own recorded reason says it needs "a hook returning `Handled` with a
`cells` key". So the proportion of row 7 purchased by the profile's emptiness went **up** as the row
got better, and the row's pass became a fourth place the vacuity leans.

**Closing a row can CONCENTRATE a vacuity rather than remove it.** No gate in this project can see
that: every individual reason stayed true, every row's prose stayed accurate, and the aggregate claim
— *what does this green table actually rest on* — is not an artifact anything computes. **The
detection is to enumerate the surviving exemptions across all rows and ask, of each, why it survives;
the fix is to make the aggregate a checked output rather than prose.**

**S20. For a generator, assert what its output is a function OF — not only that it is a function.**
Earned by WI-D4, and it is the deepest defect this project has found. All three generating seams
salted every choice with `n=${List.length(state.log)}` — the RAW log length, which the DRIVER also
writes into. Verified at review against the pre-D4 tree: `ports.ail:932` (tool), `ports.ail:1025`
(approval), `stub_step.ail:481` (provider), plus the budget at `ports.ail:982`. **So a generated
trajectory was a function of how many times the driver happened to read its configuration.**

**Determinism is not merely blind to this — it is actively reassuring.** The same seed gave the same
trajectory on every run, every time, throughout. *"The same seed gives the same program"* was TRUE
while *"the program is a function of the seed"* was FALSE. Nothing reveals it until an unrelated change
moves the driver's read count, and then it presents as **fixture drift**: WI-D3's routing reshuffled
the entire fixed bank, `ToolCorrelationMismatch` stopped being reached by the two seeds pinned as its
witnesses, and `seeded_generator` went red on six checks whose symptoms all read like stale pins.
**Giving `rich` more budget made its trajectory SHORTER**, which is the observation that found it.

The fix is to count only what the generating adapters author — D4's
`dst_interaction.generator_authored_count`, derived from `identity_kind` rather than three string
literals. **The rule generalises past generators: where a component's output is salted or bounded by a
quantity, assert what contributes to that quantity, because a wrong contributor is invisible to every
determinism check and surfaces later as someone else's regression.**

**S19. A gate's success markers are an INVENTORY, and a missing tick is a failure report.** Earned by
WI-C4, and it is the first defect in this project that turned *nothing* red — it printed one fewer
line. `make event_vocabulary` ran its unit suite as
`ailang test X > /dev/null && echo "  ✓ X"; \` in NON-TERMINAL position. Under `set -e` a failure on
the left of `&&` does not exit — that is what `&&` is for — and the following `;` discards the status.
So the target printed no tick for that file and **exited 0**. The same form in TERMINAL position is
safe, because the recipe's status is the last command's, and that asymmetry is why it survived
seventeen sites and eight items: eleven were fine and the pattern read as uniform.

**What it hid:** `test_logical_gap_is_recorded` was RED from WI-C3 — which flipped
`StreamDelta.reaches_trace_today` without updating the pinned literal beside it — until WI-C4 found
it. **Two consecutive execution reports state that every `make dst` target but two passed.**

**Measured rather than inferred:** six sites were non-terminal; all six were run directly and
**exactly one was masking a real failure**. All six are now checked commands.

**Reproduced end to end at review, because a rule this cheap to state should not rest on one run.**
The swallow: `bash -c 'set -e; false > /dev/null && echo tick; echo END'` reaches `END` and **exits
0**. The hidden failure: the pre-C4 `dst_event_vocabulary.ail` under `ailang test` gives
`13 tests: 12 passed, 1 failed`, **exit 1**. And the repair is falsifiable — the stale assertion
against the *repaired* Makefile takes `make event_vocabulary` to **exit 2**, where the same assertion
against the old recipe exited 0.

**The transferable half is the detection, not the fix.** Every mutation rule here (S1, S7, S16) asks
what turns RED. Nothing asked what stopped printing. **Read a gate's ticks as a checklist against the
files it names**, because a check that vanishes is indistinguishable from a check that passes in every
signal this project was watching.

**EXTENDED BY WI-D1 FROM AN ABSENT TICK TO AN ABSENT COUNT — the same rule in a second medium.** D1's
central finding was not a red row: it was a **class census reading zero** where the wire read 75.
Nothing failed; a number was absent, and absent read identically to *this class is legitimately
unreachable* — which is precisely what four recorded reasons already claimed, so the zero corroborated
a story that was wrong. **A zero in a census is a claim, not an observation, and the place to check it
is a producer on the other side of the process boundary.** The same item also caught its own
measurement lying in the other direction: a shell regex `(^|,)$c(,|$)` against `classes=ToolFailed,…`
never matches a leading member, so a census reported `ToolFailed` at 0 of 260 and sent the session
hunting a defect in `world_tool` that did not exist. **Both halves of the lesson are the same: a zero
is the cheapest thing for a broken instrument to produce.**

**CORRECTION APPLIED AT REVIEW: THE RECORD-FIELD GAP IS NOT NEW, AND THIS PROJECT FILED IT.** WI-D8
records it as *"THE FINDING THAT WAS NOT IN THE MISSION, AND IT IS THE BIGGEST ONE"* and lists
*"filing the record-field lambda gap upstream"* as owed. **It was filed on 2026-08-02 at WI-A3 as
ticket `fb_74f53de3ae65854c`**, and the ADR carries the original repro — `{ ai_step: \s. { let _ =
println("EFFECT PERFORMED: ${s}"); "ok" } }` — which is a **record-field lambda**, D8's construct
exactly. B4 already named its *declaration-side view*, and the plan references the ticket at three
other places. **Do not file it again.**

**What IS new in D8, and it is worth having:** the **four-position matrix** — top-level, `let`,
argument, record-field, with only the last unchecked — where A3's repro contrasted a record-field call
against a direct call; the finding that an **empty row on a lambda reads as *unannotated, infer*
rather than as *performs nothing***; and the consequence measurement, that D6's and D7's recorded
enforcement prize holds for roughly **half** their bindings. **Reproduced independently at review:** a
field declaring `! {IO}` bound to a lambda performing `Env` and `IO` type-checks clean when the
enclosing row absorbs both, while the *identical body* bound as a named function is rejected with
`Effect checking failed for function 'named' … Missing effects: Env`.

**The lesson is the project's own, one more time: a fact recorded correctly in one place was
rediscovered in another because nothing connected them.** A3 filed it, B4 characterised it, the plan
cites the ticket three times, and D8 met it fresh — which is why the four-position matrix is a
contribution and "not filed" is not.

**FOURTH EXTENSION, FROM WI-D9, AND IT IS ABOUT THE SUBJECT'S TYPE RATHER THAN ITS SYNTAX: an
instrument must exercise the subject through the same TYPE DECLARATION the subject uses.** A probe
over a *locally declared copy* of an imported record measures a different language. Measured at D9 and
reproduced at review: the ADR's own record-field repro at `:1404-1410` is a property of a **local**
`type Ports`; through the **imported** `ExtPorts` the same rowless caller is **REJECTED** with
`Missing effects: AI, IO, Trace`. **So the ADR's stated mechanism — "`ExtCtx.ports: ExtPorts` is
exactly that shape" — is false of the ABI**, and three decisions have cited it since B4 without
re-running it.

**Every conclusion the ADR draws survives on a different mechanism**, which is the inert *inline* row:
verified at review against the shipped `ExtPorts`, an annotated inline lambda declaring
`! {AI, IO, Trace}` on the real `ai_step` field, whose body reads `Env`, **type-checks clean** when the
enclosing row absorbs it. **The gap is real; the ADR's account of why is not.** This reviewer's own
four-position matrix reached the right conclusion through a local type and would not have transferred
had the claim been the ADR's.

**EXTENDED BY WI-D8, AND THE EXTENSION IS ABOUT THE SUBJECT'S SYNTAX RATHER THAN THE CHECK'S
PRODUCERS: an instrument must exercise the subject in the FORM the subject is written in.** C5's
version of S16 was about a check's two sides sharing a producer; D6's was about a producer's reach
over a subject set. D8's is narrower and sharper. `run_declared_vs_performed.sh`'s two-sided control
emits `export func mutant_hook(...)` — a **top-level function** — and every hook in this tree is bound
as a **lambda in record-field position**. **AILANG effect-checks the first and not the second**, so
the control is sound, its rejection is real, and it demonstrates an enforcement that does not exist at
roughly half the binding sites. **A control in the wrong syntactic form is green for exactly the
reason a control in the wrong process was.** Measured across four positions — top-level, `let`,
argument, record-field — only record-field is unchecked; and separately, an EMPTY row on a lambda is
not a claim at any position, because it reads as *unannotated, infer*.

**AND THE COROLLARY, WHICH IS S1's: A COMPILER GUARANTEE IS A CLAIM ABOUT A LANGUAGE AND IS
FALSIFIABLE THE SAME WAY A COUNT IS.** WI-D6 and WI-D7 each recorded "a binding that starts reading
`Env` in this slot now fails to build", each from a control that demonstrated it once in one form.
**D8 measured the fraction: 7 of 15 for `on_pre_step`, 11 of 15 for `on_budget_plan`, 8 of 15 for
`on_response_intercept`, 9 of 15 for `on_solver_candidate`.** The enforcement is real but it lives on
`register_with_config`'s row rather than on the slot's for every inline binding — and `Env` is
admitted by all fourteen registration rows that exist, so the one effect all three items narrowed
against is the one still absorbed everywhere. *When an item's prize is "the compiler now enforces X",
probe the enforcement in every syntactic position the subjects actually use, and assert the
fraction.*

**AND S22 BIT AGAINST A DERIVATION RATHER THAN AGAINST PROSE, WHICH THE RULE AS WRITTEN DOES NOT
COVER.** D8 derived its site set from source exactly as S22 requires, **and the derivation was still
wrong by three**, because it classified a site by the return type named on the same line — which
lambda-form bindings do not name. *Suggested: a derived set needs its own falsifier — an assertion
that the residue is EMPTY — not just a derivation.* That residue row is what found the three.

**S17. A mutation loop must save and restore by FILE COPY, never by `git checkout`.** Earned by WI-C3,
which lost the item's entire implementation to `git checkout src/core/session.ail` used to revert a
mutant, and recovered only from a `cp` taken seconds earlier in the same command block. **During an
item the working tree IS the work and git is the only copy of the state before it**; a path-scoped
checkout does not distinguish the mutant from the ninety minutes underneath it. S8 already asks items
to budget mutation loops as the cost of a detector — this is the operational half.

**AND A COUNT COMPARISON NEEDS AN ORDER CLAIM BESIDE IT — measured twice, one item apart.** C3 kept
`stream-parity-count` and `stream-parity-order` as separate rows and said why: a reordering leaves the
count identical. WI-D2's first wire gate forgot the lesson one file over, comparing per-variant counts
alone — and its own M3 mutant, a log appended in the **wrong position**, left **eighteen count rows
green** with only a pinned order sequence catching it. The order pin was added *after* the mutant was
written; the first version would have shipped over it. **An aggregate that survives a permutation is
not a check on a sequence.**

**S13. Sweep the whole tree before believing a gate — `check_core` is a SUBSET gate, and the sweep is
the step every item under budget pressure drops.** Milestone B found five frontiers and **the fifth
differs in kind**: the first four were found by a compiler that could not reach them yet; the fifth was
found by nobody for two items, because eleven files were red that nothing in `src/core/` imports. B2b
dropped the sweep and said so; B4 ran it first and it refuted the wave's green claim in ten minutes —
**and five of the eleven were files B2b had itself edited and left broken**, including the five
classifier-2 fixtures B2a had found the same way one item earlier. **A repair loop seeded from the
failing set cannot see what its own change breaks.** That lesson has now been learned twice and lost
once. Run the sweep cache-cold (S9), and run it *first*.

**AND RUN IT WITH `AILANG_RELAX_MODULES=1`, which no prior report records and which is worth 76
files.** Every module under `packages/**` declares a `sunholo/...` module path that does not match its
file path, so a bare `ailang check` reports MOD010 on all of them. Measured at WI-C3: the unflagged
sweep reads **146 pass / 93 fail**, the flagged one **222 / 17**. That is a false red four times larger
than the fifth frontier B4 found, and it would consume an item's remaining budget chasing a break
nobody made. The sweep is:

**AND `.ailang/cache` IS PER-SOURCE-DIRECTORY, so clearing the root one is NOT cache-cold.** Added
by WI-C5. At HEAD there are **20+** cache directories under `src/`, `scripts/`, `packages/` and
`tools/`, plus `~/.ailang/cache`. A partially-cleared tree produced a **type error that contradicted
the source**, survived `ailang lock`, and vanished the moment every cache was cleared — which is the
trap the "Traps carried forward" list already names ("clear `.ailang` caches before believing type
errors that contradict source") without saying where the caches are. The command is:

```bash
find . -type d -name cache -path "*.ailang*" -exec rm -rf {} +
```

**DO NOT ALSO DELETE `~/.ailang/cache`.** It is not only a compilation cache: it holds the
**installed registry packages** under `~/.ailang/cache/registry`, so removing it UNINSTALLS every
registry dependency (`sunholo/logging` is the one this repo has). WI-C5 did exactly that, and the
repair was worse than the damage — **`ailang install <pkg>` is NOT IDEMPOTENT: it appended a second
`"sunholo/logging" = "0.4.0"` line to `ailang.toml`, and a duplicated key in `[dependencies]`
silently breaks `pkg/` resolution across the ENTIRE tree**, with an error
(*"requires ailang.toml and ailang.lock"*) that names neither the duplicate nor the file. That cost
about fifteen minutes and four wrong hypotheses. If a registry package does go missing, reinstall it
and then **check `git diff ailang.toml`**.

**And the MECHANISM, measured at review and worth more than the flag: a WARM CACHE MASKS `MOD010`
COMPLETELY.** Same file, same command — `packages/motoko-ext-abi/types.ail` passes cache-warm
without the flag, 12 of 12 sampled package files fail `MOD010` cache-cold without it, and 12 of 12
pass cache-cold with it. **So the flag's necessity appears ONLY under the discipline S9 and S13
impose**, which is exactly why three items measured sweeps without ever needing it. Cache-warm and
unflagged fails *green*; cache-cold and unflagged fails *red* by 76 files — **opposite directions,
which is why neither reads as a defect on its own**, and only cache-cold with the flag is the real
number.

**`cmd` is not a root in this repo and is removed from the command below** — it produces a spurious
error and a non-zero exit from `find`, which is reason enough not to name it.

**But the consequence WI-C5's report drew from that is WRONG, and it is corrected here rather than
carried, because it is alarming in the direction that would void every sweep this project has
recorded.** The report says this environment's `bfs` "aborts the whole traversal", so the loop
"iterates over nothing" and the sweep is "a perfect green having checked not one file."
**Measured — `bfs 4.1.1` does not abort.** With the missing root in first, middle or last position
the traversal returns **242 files every time**, identical to the command without it, and the exact
`for f in $(find src scripts packages tools cmd -name '*.ail' | sort)` loop iterates **242** times.
Nor is it silent: `bfs` prints `bfs: error: cmd: No such file or directory.` to stderr and exits 1.
**So no prior sweep measurement is invalidated, and this was not an instrument certifying nothing.**

**What it DID cost is real and is the part to carry: WI-C5 reported no whole-tree sweep at all**,
having concluded from the wrong diagnosis that the sweep was broken. S13 requires one. **A wrong
diagnosis of an instrument suppresses the measurement just as effectively as a broken instrument
does** — and unlike a broken instrument, nothing goes red.

**The missing sweep, run at review, cache-cold with the flag: `225 pass / 17 fail`.** 225 rather than
C3's 222 because `dst_hook_guard.ail`, `declared_vs_performed.ail` and `hook_guard_dst.ail` are new.
**The failing set matches the expected seventeen member for member** — 7 `TC_ARITY_001` smoke scripts,
1 sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture — so the
set is now stable across B4, C1, C3 **and** C5.

```bash
for f in $(find src scripts packages tools -name '*.ail' | sort); do
  AILANG_RELAX_MODULES=1 ailang check "$f" >/dev/null 2>&1 || echo "FAIL $f"
done
```

The 17 expected failures are stable across B4, C1, C3 and C5: the 7 `TC_ARITY_001` smoke scripts, the
sealed-vocabulary probe (`IMP010`), 5 `src/examples/`, 3 code-graph fixtures and 1 test-coverage
fixture. **Confirm the failing set member-for-member rather than the count** — the count moves by one
whenever an item adds a file.

**AND S9 REACHES ONE DIRECTORY TOO FEW: THERE IS A COMPILE CACHE BESIDE THE STDLIB, AND
`effect_inventory_selftest`'S ANSWER IS A FUNCTION OF IT.** Measured at the acceptance-reviewers'
governance act and pinned at review. **Three sessions ran the same gate on the same tree today and got
three different answers** — `agree=0` (this reviewer), `agree=1` (both acceptance reviewers, four
consecutive runs), `agree=45` (this reviewer again, hours later). Not one of them is a fact about the
tree.

**The variable is `/home/motoko/.local/share/ailang/std/.ailang/cache/`**, which held **230 files
written that day**. It is outside S9's sweep by construction: the sweep runs from the repository root
and excludes `./ailang/` and `./tools/code-graph/`, and this path is under `~/.local/share`.
**Demonstrated two-sided:** clearing it takes the selftest `agree=45 → agree=1`, and restoring the
230 files takes it back to 45. `std/env` is the one module that resolves cold, which is the
acceptance reviewers' unexplained observation, explained.

**So both of the competing findings about classifier 1 were readings of cache warmth.** *"Its
acceptance criterion is NOT met at HEAD"* (WI-D10) was true at `agree=0`; *"the criterion is met and
that is worse than the red"* (the governance act) was true at `agree=1`. **The gate measures the
cache, not the tree** — and the amended ≥90% criterion inherits the same defect, because its numerator
is *modules `ailang iface` can resolve*, which is exactly what the cache decides. **S9's sweep needs
this path, and any coverage criterion over `ailang iface` needs a cache-state precondition.**

**AND A GATE THAT IS NOT IN `make dst` DEGRADES INVISIBLY, however loudly it fails when run.** Found
by the amendment review, outside its scope. **Classifier 1 — the ADR's one *built* gate mechanism —
does not meet its recorded acceptance criterion at HEAD.** The ADR's gate-mechanism table — classifier
1's row was `ADR:2110` when the review wrote this, is `ADR:2397` after WI-D10's amendment — recorded
it *"Built and independently verified … Met at `a0d4edb`, run by both acceptance reviewers: 0
unresolved, `agree=43 disagree=0`"*, and its criterion has two clauses. **Verified at review and again
at WI-D10: `make effect_inventory_selftest` exits 2 reporting `agree=0 disagree=0` and "This is a
pass-shaped absence, not a pass"** — all 46 `ailang iface` calls fail `MOD010`, so every classification
comes from an unvalidated textual fallback. **Neither `effect_inventory` nor
`effect_inventory_selftest` is in `make dst`**, so thirty-three items ran without seeing it, across a
toolchain repin the Makefile itself says to re-run after. **The tool failed closed correctly and said
so in plain words; nothing was listening.** A gate's loudness is worth nothing if no aggregate target
invokes it. **WI-D10 annotated the row and left the repair owed and unowned.**

**AND A SOURCE-DERIVED GATE HAS ITS OWN HAND-MAINTAINED INPUT — the literal the gate cannot see.**
Earned by WI-D3. `make discovery` re-derives `driver_env_keys()` from source rather than trusting a
literal, which is the right shape; but **the FILE LIST it derives from is itself a literal nobody
re-derives.** It named two files, the driver's env surface had moved into a third, and the derived set
came back four keys short. It failed *loudly* — a derivation with a wrong input disagrees with the
literal it checks rather than agreeing with it — but that is luck of direction, not design. **When a
gate derives a claim from source, ask what tells it WHICH source.**

**S12. An identity transition is the correct answer for a component that did nothing and a silent
defect for one that did something — and no type distinguishes them.** Earned by B2b, and it is the
band B2a's closed-row argument does **not** cover. That argument holds and was re-confirmed: closed
rows admit exactly one width, so not one of B2b's 181 rowed sites had two answers. But B2b changed the
*shape* of results, not just their rows, and `next_state: ctx.world` type-checks everywhere. Two
instances, both in the one hook in the tree that actually calls `ai_step`: a re-wrap that **discarded
the world the summarizer advanced** (F6, again), and **failure branches returning the entered world
after attempts had been made and script entries consumed** — *the decision falls back; the world must
not.* Both pass every test in the tree. B2b's shipped mitigation is comment-level and says so:
**a real instrument is an assertion that a component which performed a call did not return the state
it was given**, which needs a counter the token does not carry. **Where you cannot build the
instrument, say the mitigation is weaker than a check rather than letting a comment read as one.**

**S12 NOW HAS ITS INSTRUMENT, and WI-D1 built it by accident while closing a fault class.** B2b said a
real check "needs a counter the token does not carry". **The counter is a recorded fault class that
only exists if the world was threaded.** `session.c2_loop`'s unretried-provider-failure branch
finalized from `st.world_state` rather than `exchange.next_state`, discarding the interaction the
recording adapter had just appended — **75 provider-failure finalizes on the wire against ZERO
recorded `provider_error_non_retryable` records**, with the retry branch immediately above, threading
correctly, as the control. Wrong since B2b and invisible to every gate until a class needed that log
entry. **Verified independently at review: reverting the one expression to `st.world_state` removes
the class from every bank member and reddens `make corpus_pr`; restoring it brings the class back at
seeds 3 and 36.** The generalisation: **to instrument an S12 site, give the discarded state something
to carry that a gate demands** — the defect is unobservable as state and obvious as a missing count.
The edit was line-count-neutral on purpose (S18), so no anchor moved and no profile was re-issued —
the first item in four to avoid the cascade rather than pay it.

**Two sibling sites are known and unfixed**, reported rather than repaired because no profile in this
tree reaches them: `SealSystemPromptEmpty` and `SealExhausted` discard `chain.next_state` the same
way, ~100 lines above, violating a rule the same file states twenty lines below them.

**S11. `export type X = X` is prohibited where `X` is a record — it resolves to itself and fails at
every construction site, never at the cause.** Earned by B2a, which found two instances. v0.33.0
accepts the alias at its declaration and treats it as unexpandable thereafter, so the error surfaces
as `cannot unify record with unexpandable type constructor X` at each *use*, arbitrarily far from the
re-export. `dst_program.ail`'s `GeneratorBounds` blocked 8 files; `stub_step.ail`'s `ScriptedStep`
blocked **33** — and the second was invisible because every one of them died on an effect row first.
B2a's own first reading called it "a latent instance, safe because `ScriptedStep` is an ADT matched by
constructor"; it is a record, and the compiler corrected the comment. **The prohibition is on the
form, not on the symptom: it is a defect wherever `X` is a record, whether or not the tree is
currently green.** Repair by removing the re-export and repointing importers.

**Second clause, from B2b — the same species with a different shape: a type declared locally in a
module that imports another module declaring the same NAME is silently shadowed by the imported
one, and the local declaration is dead.** B2b's structural-versus-nominal probe passed on its first
run **and so did three mutants** — an extra record field, an extra sum variant, a changed payload
type — because the probe's local types were being silently replaced by the imported ones it was
comparing against. The probe looked like a result and was inert. Only renaming the types apart
produced the real answer (records unify **structurally**; sums are **nominal**). **Both clauses are
one defect: a declaration the compiler accepts and then quietly discards.** The control that failed
is what separated a finding from a fiction, and it was nearly skipped.

**S10. Drive tooling off the compiler's VERDICT, never off its prose — a diagnostic's labels are an
interface, and this one is context-dependent.** Earned by WI-B3. `ailang check` reports
`expected`/`actual` in an order that **flips by error context**: under a `let`/`return type
annotation` the *literal* is `expected`, while under `function application, parameter N` or
`list element N` the *parameter type* is. So the identical text `extra fields: images` means **add**
in one context and **remove** in the other — and the `Hint:` is derived from whichever order was
used, so **on every revert site the hint reads "add the field(s) to the literal" when the fix is to
delete it.** A fix loop reading those labels re-added the field to three sites that had already been
correctly reverted, then oscillated thirty times on a fourth. The repair was to stop reading labels
entirely: **flip the literal and ask the compiler whether that site's error moved.** That is immune
to label order, it converged in 60 edits, and the one site it could not satisfy turned out to be a
genuine implicit crossing rather than a shape problem — which is information the label-reading loop
could never have produced.

**AND THE SWEEP MUST COVER THE DEPENDENTS OF AN EDITED INTERFACE, NOT JUST THE EDITED MODULE.**
Earned by WI-D16, which lost ~25 minutes to a record-field error **whose subject was wrong in two ways
at once**. `long_qwen_compaction_dst.ail` reported *"expected 5 fields, got 4 … missing fields:
file_read"* **pointing at a literal that had all five**, because `expected` is the LITERAL and `actual`
is the ANNOTATION's type — the reverse of the message's natural reading and of its own `Hint:`, which
tells you to add a field that is already there. **And the stale 4-field `ExtPorts` was not in the ABI's
own cache**: it reached the failing module **structurally embedded inside `compaction_ai`'s cached
interface**, so deleting the ABI's cache entry in all 29 directories did not fix it and only a sweep of
the *dependents'* caches did. **A session that trusted the message would have edited correct source.**

**S9. Clear EVERY live `.ailang/cache` before believing any check whose input you just mutated —
they are per-directory, and `rm -rf .ailang/cache` clears one of them.** Four phantoms now, and B2a's
is the one that establishes the rule's real shape. **`rm -rf .ailang/cache` clears only the ROOT
cache.** AILANG writes one cache per compiled source directory — `src/core/`, `scripts/`, each
`packages/*/`, and so on — so a repo-local clear leaves the rest warm. At B2a that produced a **false
red that survived five wrong hypotheses over roughly forty minutes**: `check_core` fell 51/51 → 44/51
and stayed there through a repo-local clear, a full `sync_packages`, a `.packages` rebuild, an
`ailang lock` refresh, and two source-level theories. The cause was a stale per-directory cache
holding a pre-`Trace` interface; clearing them all fixed it with **no source change**.

Use a sweep, not a path:

```bash
find . -type d -name cache -path '*.ailang*' \
     -not -path './ailang/*' -not -path './tools/code-graph/*' -exec rm -rf {} +
```

**Two exclusions. `./ailang/` is load-bearing** — a git-ignored clone of the compiler, not ours.

**The `./tools/code-graph/` exclusion's stated rationale was WRONG, and WI-C1 corrected both the
rationale and the condition that made it matter.** The claim was that the `.ailang/cache` directories
there hold "deliberate test fixtures, read by `test_source_index.py` and `test_precision_recall.py`".
**They are not read by anything** — measured: both tests read the fixtures' `.ail` SOURCE files
(`build_source_index` walks the fixture directory; `test_sample3_precision_recall` reads
`fixtures/sample3`), and no Python in `tools/code-graph` mentions `.ailang` or `cache` at all.

What the caches actually were is **accidentally committed build output**, twice: B2a's `7bca61c`
added 34 files, B2b's `eed1d7c` deleted them, and B4's `072bb05` added 34 again — because
`.gitignore`'s `!tools/code-graph/**` re-included the whole subtree, so a sweep's compile output
showed up as untracked files asking to be committed. **That inverted this very rule**: the exclusion
written to protect fixtures was instead protecting tracked stale caches, which is what S9 exists to
condemn. And a tracked cache is the one file class that *does* create the cross-branch hazard this
rule's own correction says does not exist — a fresh checkout starts with a stale cache it never
built.

**Fixed at WI-C1 (`10b9583`):** `tools/code-graph/**/.ailang/` is now ignored explicitly and the 34
files are untracked. **Keep the exclusion anyway** — it saves recompiling fixtures on every sweep —
but it now means only what it says, and there are **no tracked `.ailang/cache` paths anywhere in the
repo.** B2a's proposed version of this rule omitted the exclusion.

**Correcting B2a's framing, because it is alarming and wrong in the direction that matters:** its
report says the caches "are TRACKED IN GIT … they travel between branches … a phantom no per-session
discipline can catch." **The live caches are git-ignored** — verified with `git check-ignore` on both
that exist. The only tracked `.ailang/cache` paths are those code-graph fixtures. **A stale interface
does not arrive by checkout**, and no cross-branch hazard exists. **Do not cite a fixed count
either:** the number of live cache directories is however many source directories have been compiled
— two at the time of writing, not 34, which was a tracked-*file* count read as a directory count.

**Carried forward from the three phantoms that came before B2a's, because the rewrite dropped the
reason the rule exists.** The first two corrupted a *diagnostic*: a stale cache reported row
mismatches against source that was already correct, once across a stdlib change and once across a
compiler version change, and clearing fixed both with no source edit. **WI-B1's corrupted a
*detector*** — its mutation loop dropped `Rand` from the ABI row and read **GREEN on a warm cache and
RED on a cold one**, so the verdicts were partly cache artifacts and it nearly argued for reverting a
correct, load-bearing ABI change. **A stale diagnostic is noise; a stale detector inverts a verdict**,
and C5 mutation testing is required by most remaining items. That is why this rule is not merely
hygiene. **Bookkeeping note, found at WI-C1:** this plan carried TWO copies of S9 and S10 from
`d7c6dd0` until now — B2a inserted its rewritten pair without deleting the originals, so the older S9
survived three items with different text and neither copy was marked superseded. The duplicate pair is
removed and the unique content above is the merge. **It is S15's defect one level up: a superseded
rule and a current one look identical.**

**The retroactive consequence stands and is the part to carry:** every whole-tree sweep this project
has recorded — B1's 130/105 and its v0.26.0 baseline of 213/22, B3's 161/74 — cleared the root cache
only, so **none is the cache-cold measurement it claims.** They are not necessarily wrong, since a
warm cache only misleads when its input changed, but they are not what they say.

**AND BEFORE BELIEVING ANY GATE, CHECK THAT NOTHING ELSE IS RUNNING ONE.** Earned by WI-D4, which
found a second Claude session with a `make dst` in flight in the same working tree at session start.
The `.ailang` caches are shared and the recipes write hard-coded `/tmp` paths — `/tmp/corpus_pr.out`,
`/tmp/latency_pair.out` — that two runs overwrite under each other. **Every measurement the item needed
would have been poisoned, and nothing would have said so.** The item stopped its own run and waited.
Concurrency in one tree is a measurement hazard of exactly the kind S9 exists for, and it is invisible
in the same way a warm cache is.

**S8. When a guard asserts that X influences Y, check that X cannot reach Y except through the
mechanism under test.** Earned by A13 stage 4, and it is the first rule this project has that
mutation testing (C5) structurally could not produce. The generator's whole risk is a seed that
reaches no choice, so the stage's central assertion is "changing the seed changes the program". It
was written first (S1), it was proven red against the intended mutant — a real driver run whose
generator state is identical across three requested seeds — and it **still passed** on a weaker
mutant, because `choose_provider` printed `g.seed` into the generated prose. Patch the PRNG's
seeding to ignore its seed entirely and three seeds produced *the same interaction count, the same
draw count and the same clock* — identical trajectories — with three different outcome digests. A
generator that reads its seed only to print it satisfies every statement of seed sensitivity that
compares programs.

**The complement, from stage 5, and it is the cheaper of the two to fall into.** Site 21 was a
**decorative path** — X reaching Y *around* the mechanism. The mirror is that **the mechanism has
branches the assertion's trajectory never enters, so X could not reach Y at all.** Stage 5's first
canary caught five of six mutants; the escape changed what a bound failure *reports*, and it escaped
twice for two different reasons: the trajectory's bounds were generous enough that no limit was ever
tripped, so the branch was outside what the digest could see; and once the branch was reached, the
digest folded `|F${length(failures)}` — a **count**, blind to a change in a **field**, which is S7's
record-level form arriving on a digest instead of a codec. **A pinned digest certifies exactly the
paths its trajectory walks; the paths it does not walk are not pinned, they are *absent*, and absent
reads identically to unchanged.** So: choose bounds tight enough to bind **for every seed** rather
than for a lucky one — a limit no draw can reach is a branch the digest cannot certify — and fold
every field, not a count of them. The decorative path needs an author to write something decorative;
the unwalked branch needs only that they not think of it. **A14's latency pair and A15's corpora both
have this exposure.**

**The SEQUENCED-CLAUSE form, from A17, and it is the cheapest instance to get wrong.** Where a guard
is an ordered chain of clauses, **an input that a later clause also rejects cannot certify an earlier
one** — delete the earlier clause and the row stays green. Site 23 recorded this for `has_jwt`'s two
conjuncts; A17 committed it twice more in a three-clause chain, *by a session that had read site 23
that morning*. Its dual is site 32: **a control that must SURVIVE certifies nothing if the mechanism
never reached it** — dropping a fixture from the walk entirely left every row passing, because absent
and correct are the same observation. Operationally, and it is cheap: **for a guard of N sequenced
clauses, each control must be rejected by its own clause and ACCEPTED by all the others; and for a
surviving control, assert that the mechanism SAW it, not merely that it produced no finding.**

The rule is distinct from S1 (write the assertion first) and from C5 (prove the guard can fire): the
guard here **could** fire and **did** fire on the mutant it was designed against. What exposed the
gap was mutating the implementation a *second, weaker* way — breaking only the mechanism, and
leaving the decorative path intact.

**The remedy is structural rather than a better assertion:** everything the generator writes is now
derived from a **draw**, so a seed that reaches no choice reaches no byte of the program. Where that
cannot be arranged, the assertion must name the leak and exclude it.

**And the COMPLEMENT, earned by A13 stage 5 and cheaper to fall into than the original: check that the
assertion's own trajectory ENTERS the branches it claims to cover.** Site 21 is X reaching Y *around*
the mechanism — a decorative path. Its mirror is X not reaching Y *at all*, because the mechanism has
branches the assertion never walks. Stage 5's canary pinned a digest over a generator trajectory that
never spent its interaction budget and never tripped a declared limit, so every bound branch was
outside what the digest could see: mutating what `note_bound` REPORTS left the canary green, and so
did the second attempt, because the digest folded the failure COUNT where the change was in a FIELD
(S7's record-level form, arriving on a digest rather than a codec). **A pinned artifact certifies
exactly the paths its trajectory walks; the paths it does not walk are not pinned but ABSENT, and
absent reads identically to unchanged.** The remedy is again structural — a second walk under limits
tight enough to bind *for every input*, so branch coverage is a property of the artifact rather than
of the input that happened to be chosen — and it is why stage 5's pinned seeds were preferred among
894774 qualifying triples on trajectory coverage, the one axis the filter could not express.

**The decorative path requires an author to write something decorative; the unwalked branch requires
only that they not think of it.** A14's latency pair and A15's corpora have both exposures.

**A14's latency pair, and the third form S8 can take: the CONTROL that makes "except through the
mechanism" executable.** The pair holds a tool's request and completion result constant and changes
only `duration_ms`, so both S8 halves apply — and both are discharged by assertions rather than by
care. The decorative half: the two world inputs are compared FIELD BY FIELD and every field except
the latency must be equal. The unwalked half: the declared deadline is asserted to lie STRICTLY
BETWEEN the two latencies, so neither branch can go unentered. **What neither of those can see is
whether latency reaches the outcome AROUND the deadline comparison**, and the answer is a THIRD
world: the same 3000 ms latency with no declared deadline, which must COMPLETE. `world_tool`'s guard
is `inv.timeout_ms > 0 && duration > timeout`; dropping the first conjunct reddens that control and
nothing else in the file. **A control world is cheaper than either half and it is the only one that
tests the "except" in S8's sentence — carry it to A15's corpora.**

**The complement's cheapest instance, from A13 stage 6, and it lives inside a TEST rather than a
digest: a NEGATIVE CONTROL must fail the rule for the reason under test, not for an earlier
reason.** Site 23's `has_jwt` requires a `eyJ` prefix *and* three plausible segments; reducing it to
`contains(s, "eyJ")` left every row in the module and the acceptance suite green, because all four
negative controls were strings that **do not contain `eyJ`**. They exercise the prefix clause and
cannot reach the segment clause, so the row claimed a mechanism whose branches its own trajectory
never entered. **A control rejected by clause 1 certifies nothing about clause 2 and reads
identically to one that exercises both.** Site 24 is the same shape one level up: "a one-field change
moves exactly two lines" is the right quantity for diffability and is green on a single-line encoding
too, because a one-line body also differs in two lines — repaired with a floor **derived from the
artifact** (four lines per interaction) rather than a chosen constant.

**Both of A13 stage 6's sites are assertion weaknesses rather than implementation defects, which is
now the majority shape in this project.** The implementation was right both times; the evidence that
it was right was not. And both were found by mutating the implementation and reading **why** a row
went red — never by running a gate. **Budget mutation loops as the cost of a detector, not as
verification after one.**

**A14's D4 latency pair and A15's corpora both assert "this input influences that artifact" and both
have this exposure.** So does stage 5's generator canary, whose failure mode the handoff already
named — pinning `generator_id`, `generator_version` and `seed` as literals passes and certifies
nothing. S8 says the canary must pin something the version cannot reach except by changing a choice.

**S4. Size a constructed artifact by the rows whose content must be *discovered*, not by its row
count.** Cluster 3 measured the controlled comparison: A7 has 68 sites and took 11.5 minutes; A8 has
158 and took 8. Every A7 row needed a recovery branch located and confirmed in the driver — eleven
separate investigations — while A8's thirty-four rows were transcribed from a projection function
already open, one classification judgement each. **Price discovered rows at roughly a minute each
and transcribed rows at negligible.** New-artifact sites are markedly *cheaper* per site than
widen-and-converge sites (7.6–19.8/min against 3.4), because an artifact row costs no compiler
round-trip — so the site model does not transfer, and the surprise runs opposite to the direction
the plan hedged against.

**S5. Size a detector by its defect-discovery round trips, weighted by how loudly each defect
fails — and accept that it cannot be sized before it runs.** This is the property that distinguishes
detector work from the other two kinds: a widen-and-converge site and an artifact row are both
countable from the source in advance; **a detector's cost is dominated by defects in the detector
itself, which are invisible until it runs against real source.** Cluster 2 measured 4 / 4 / 1 round
trips against 11 / 8.5 / 5.5 minutes — a better predictor than lines or files. The weighting matters
more than the count: A5's four round trips were compiler errors with line numbers; A4's four each
produced a **plausible report** that had to be read and disbelieved. Budget loud defects at
near-zero and silent ones at the cost of noticing them.

**S6. Size a COMPOSITION by the number of INPUT ARTIFACTS whose exports must be read before a line
can be written — roughly 2-3 minutes each — plus its RECORDED bindings, which are the only ones that
cost anything after that.** This is the fifth kind, after widen-and-converge, constructed artifacts
and detectors, and A10 measured it: **four round trips, all loud, zero silent defects — and thirty
minutes**, roughly half of it grounding. S5 would have priced that at minutes and S4 at nothing,
because **both assume you already know the source you are working in, and composition's whole job is
to be correct about somebody else's artifact.**

**Generalised by A13 stages 1 and 2, and it is what makes S6 transfer beyond A10:** a *recorded
binding* is not only a value that must be copied — it is **any fact that cannot be read and must be
decided.** For A10 those were an attribution identity and two derived sets. For a validator it is a
specification clause admitting two readings; stage 1 had exactly one (D2's duplicate-identity rule)
and it consumed effectively all the item's risk while twenty-odd read bindings cost nothing. Stage 2
had **three** and cost roughly **3×** stage 1 — the count of recorded bindings tracked the cost ratio
better than any measure of size. **No sixth model is needed; count the decisions, not the lines.**

**Fourth data point, and the second term needs one distinction.** A13 stage 4 had **four** recorded
bindings against stages 1–3's three, and cost roughly **1.5×** stage 3 — the count predicted 1.33×
and the direction is right, so the predictor survives a fourth time. What it did not predict is that
**two of the four were DISCOVERED by running rather than decided by reading.** Bindings 1 and 2 (how
the request enters a choice; what `max_resource_size` bounds) were identifiable from D2 before a line
was written, exactly like every binding in stages 1–3. Bindings 3 and 4 (end-of-input is terminal;
where the generator's choice surface stops) both arrived as **red gates** — one from strict replay,
one from a chosen field that nothing consumed. **No sixth model: S6's second term inherits S5's
uncertainty whenever the composition is over something that RUNS rather than something that
validates.** A validator's bindings are all decided; a generator's are not, and cannot be counted in
advance.

**Fifth data point: apply the second term PER PIECE, not per stage, when a stage's pieces are
independent.** Stage 5 had five bindings (three decided, two discovered) and cost **~0.9×** stage 4
against a predicted ~1.25× — **the count over-predicted for the first time**, and the reason is
legible rather than noise. Its two pieces do not interact: regression replay cost well under a third
of the session despite carrying two bindings' worth of care, because stage 3 had left a seam that
fitted a parameter; the canary was ~70% of it, all of that in the discovered bindings and the
sweep/re-pin loops they forced. **Summing bindings across independent pieces and comparing the total
to a previous stage's total predicts the average of two things that never touch.**

**Seventh data point, and the widest spread yet — the discovered count predicts and the total does
not.** WI-A14's three pieces carried 7 bindings (4 decided, 3 discovered), 6 (4, 2) and 4 (4, 0), and
the measured windows are **56, 12 and 10 minutes**. The totals predict roughly 56 : 48 : 32; the
discovered counts order them correctly and get the shape roughly right.

**And A14 adds a finding to S6's FIRST term rather than its second: grounding is paid PER SESSION,
not per piece.** Piece 3 — a new module, a new acceptance script, a make target with three structural
guards and thirteen mutation rows — cost **twelve minutes**, the cheapest composition this project
has measured, because piece 1 had already read every input artifact it needed (the catalogue, the
profile, the persistence store, the discovery witness). **That is an argument for cutting items by
SHARED INPUTS rather than by obligation**, and it is the same shape as cluster 12's finding that A13
stage 6 was two pieces sized as one.

**Sixth data point, and it refines the second term rather than adding a model: weight by DISCOVERED
bindings, not by the total.** A13 stage 6's two pieces carried 4 bindings (3 decided, 1 discovered)
and 6 bindings (5 decided, 1 discovered); the count predicts 1.5× and the measured cost was 0.95×.
The reason is legible and matches stage 5's: **a decided binding whose deciding artifact is already
open is close to free** — stage 6's five decided bindings were each read off D8 and the standing
rules with the ADR open, and cost a paragraph of comment each — **while a discovered one costs a
round trip through running the thing.** Discovered counts of 1 and 1 against costs of 21 and 20
minutes predict better than totals of 4 and 6, and the same holds retrospectively for stage 5 (2 and
0 discovered against ~70% and <30% of the session). The first term is unchanged: grounding is still
paid per input artifact whose exports must be read.

**And a measurement correction that applies to every ratio in this plan.** A13's six stages have now
been read off git as **wall-clock windows** (handoff commit → last `feat` commit): 34, 43, 35, 60, 36
and 41 minutes, giving ratios 1.26×, 0.81×, 1.71×, 0.60×, 1.14×. **The contemporaneous reports gave
~3×, ~1×, ~1.5×, ~0.9× — and they over-report by two to three times wherever a stage's cost was
DELIBERATION rather than running things.** Stage 4, the one stage dominated by sweeps and re-pins, is
the only one where the two agree. Future reports should give the git window, which is checkable, and
may give a felt ratio beside it, which is not.

**Fourth data point, and the second term needs one distinction: a *decided* binding differs from a
*discovered* one.** Stage 4 had four bindings against stages 1–3's one, three, three, and cost ~1.5×
stage 3 — the count predicted 1.33× and the direction held. What it could not predict is that **two
of the four arrived as red gates rather than from reading the specification**: that end-of-input is
terminal (site 20, a property of the world model that only a replay revealed) and where the
generator's choice surface stops. Stages 1–3's bindings were all identifiable from the artifacts
before writing code. So: a decided binding costs a judgement; **a discovered binding costs a
judgement plus the round trip that surfaced it, and cannot be counted in advance** — which is S5's
property arriving inside a composition. **No sixth model: S6's second term inherits S5's uncertainty
when the composition is over something that RUNS rather than something that validates.**

**Fifth data point, and it is the first time the count OVER-predicted — apply the second term PER
PIECE, not per stage.** A13 stage 5 had **five** bindings (three decided, two discovered) and cost
roughly **0.9×** stage 4 against a predicted ~1.25×. The reason is legible rather than noise: the
stage's two pieces were **independent**, and one of them was nearly free. Regression replay carried
real care — it is where the demotion set lives — and still cost under a third of the stage, because
stage 3 had left a seam that fitted a *parameter*; the canary consumed ~70% of the session, all of it
in the two discovered bindings and the three sweep-and-re-pin loops they forced. **Summing bindings
across independent pieces and comparing the total to a previous stage's total averages two things
that do not interact.** Count and price each piece separately, then add — and note that this also
tells you which piece is the clean stop, which is S3 applied across pieces rather than across seams.

**Third data point: the predictor survives, its explanation does not.** Stage 3 had three recorded
bindings — parity with stage 2 — and cost about the same, so the count held. But cluster 8 attributed
its 3× to "the driver wiring is where the time went", and stage 3 is *also* driver wiring while doing
strictly more (a new module, two codecs, a second acceptance script, a Makefile target). **What
actually made it cheap is not in any model: stage 2 left the seams in the shape stage 3 needed.**
`RecordingWorld`, `TracedSessionResult.world`, `class_balance` and a `check_discovery` that was
already two-sided were reused verbatim — the reconstitution balance *is* `class_balance` with
different nouns. So: **the binding count predicts cost within a stage; what it cannot see is that a
well-shaped predecessor moves bindings out of the successor entirely.** Stage 2's decision to make
its checker two-sided — which its own report notes "no artifact asked for" — is the single largest
reason stage 3 was cheap, and it was taken a cluster before the saving appeared.

*The third data point, and the limit of the predictor.* A13 stage 3 also had **three** recorded
bindings and cost roughly **1×** stage 2, which is the parity the count predicts — while delivering
strictly more (a new module, two codecs, a second acceptance script, a make target with a wire
comparison). So the predictor holds; cluster 8's *explanation* for its own 3× — "the driver wiring
is where the time went" — does not, because stage 3 is also driver wiring. What actually made stage
3 cheap is not in any model: **stage 2 left an assertion that generalised.** `check_discovery`,
`class_balance`'s one-arithmetic-site discipline and `approvals_served` were reused verbatim — the
reconstitution balance is `class_balance` with different nouns, and grading the replayed run is a
function call. **A composition's cost falls sharply when its predecessor left a generalisable
assertion, and the binding count cannot see that, because the saving appears as bindings that never
had to be made.** Stage 2's decision to make its checker two-sided — which its own report notes "no
artifact asked for" — is the single largest reason stage 3 was cheap, a cluster before the saving
appeared. Do not add a term; note that the predictor measures a stage in isolation.

*The load-bearing half is the second term.* A10 had twenty-three facts crossing an artifact boundary
and twenty of them are READ at runtime, so they cannot go stale and cost nothing measurable once the
read-don't-restate policy is taken once. **All the risk went into the three that could not be read**
— the attribution identity (recording it is the point; calling the live function makes the check a
tautology) and classifier 2's two derived sets (produced by a Python tool, so they enter AILANG as
literals). Each needed a purpose-built comparison, and those comparisons were most of the item's
non-boilerplate work. So: **a read binding is free; a recorded binding is where the item's entire
risk lives**, and a composition with many inputs and no recorded bindings is cheap regardless of its
size. Site count predicts neither — A10 is 2925 lines at four round trips.

*Corollary for the judgement ratio.* It tracks how much the specification leaves undetermined **about
the RULES**, and it is a clean signal only for an item that is all rules. A10 shipped machinery *and*
an instance and measured 14% on the machinery against 95% on the profile — because *which* adapter
boundaries a profile has is discovered from the driver, not determined by D5. **Report the two
separately;** a combined 34% reads as "the spec was vague" when the truth is "half of this item was
content, and content is never in the spec".

## Decisions this plan owns

The ADR deliberately left these decisions to the plan. They are answered here, once, so no work
item re-litigates them.

**P1. `ProviderState` is a record, not a sum.** Declared in `src/core/ports.ail` as a record whose
first field is the scripted cursor (the remaining-script tail, the threading style
`scripted_model_next` already demonstrates). **Ground: build-backed, not analogy.** A reviewer's
three-module probe on the pin widened a `ProviderState` already used in a cross-module port
signature and the port module came out **byte-identical** — the compiler flagged only the
construction site, which is the additive-edit shape this decision wants. (An earlier revision
grounded P1 on M1 instead. That citation over-claimed: M1's 7 judgement sites were about *type
identity*, `Msg` versus `Message`, and it never measured the sum alternative. The probe is the
stronger evidence and replaces it.) The live/`Ported` value is the record with an empty script;
live adapters return their input unchanged (D1's specified identity transition).

**P2. The approval and clock cursors do not ride along in the interim widening.** The decision
stands; **its ground is no-interim-consumer, not structural closure**, and an earlier revision
claimed the latter wrongly.

*Why the decision stands:* neither cursor has an interim consumer. The scripted adapter's
`approval_read` is a constant deny (`deny_approval`, `ports.ail:26-28`, wired at `:42`) with no
position to thread, and the virtual clock only exists once `world_state` lands — which subsumes and
deletes the interim field anyway (D1). Dead rider state threaded through every construction site
would be cost without a customer.

*What is not true:* that P1 closes the ADR's bidirectional-widening risk. **The structural closure
covers only cursors consumed at `model_step`**, the one port gaining a state parameter.
`approval_read` and `clock_now` have no state parameter at all (`ports.ail:19-20`), so adding a
field to `ProviderState` does not make either reachable. Two independent reviewer probes on the pin
established this: assigning a state-threaded adapter to HEAD-shaped `approval_read` fails to unify
(`function arity mismatch: 2 vs 1`), and the only shape that compiles without changing the port is
a **closure-captured cursor — which runs, freezes, and reproduces F6's exact signature on a second
port** (`served=[allow, allow, allow]`, advancing=false). That is the arrangement D1 prohibits by
name.

*The residual, stated rather than hidden:* a pre-`world_state` need for a non-constant approval or
a clock value read from interim state forces a **second bidirectional port widening**, of
`approval_read` or `clock_now`. **Trigger to reopen this decision:** any such need arising before
WI-A12. `ScriptedPortsState` (`scripted_ports.ail:20-24`) already models all three cursors and is
the design precedent if it does.

**P3. Clock routing order, and the first routed-set claimant.** Order: (1) **the core driver sites**,
routed to the world clock as part of WI-A12 — every profile needs them, and the count is deliberately
not stated here; see the correction below; (2) `ext/runtime.ail:190`
is never routed — it is *attributed* to `test_dummy` in the WI-A5 table, which is what removes it
from the baseline's reachable set; (3) the eight `motoko-ext-compose` sites are deferred to
Milestone C, because they route through `ExtPorts.clock_now` — a seam with zero call sites that may
not survive first contact — and belong with the ABI major.

**Corrected 2026-08-03 (cluster 2, C3): stop citing a fixed site count here.** The "four driver
sites" and `driver_only`'s "4 routed sites" were true when written and the source has moved **twice
inside one milestone**. At HEAD there are **five** routed core sites — A12 added `tool_phase.ail:342`
— plus **two ambient core sites that did not exist when D4's table was written**:
`session.ail:796` (`ext_unrouted_clock`, deliberately ambient under S2) and `stub_step.ail:146`
(inside `live_ports`). D4's `4 / 12 / 13` and `5 / 13 / 13` splits describe a tree A12 changed.

**The count is not the decision; the ordering is.** A validator holding its own copy of "the
thirteen sites" agrees with itself by construction and goes stale exactly when the source moves.
A5 already discharges this correctly — `make attribution_table` takes the discovered set as an
**argument**, never as a constant, and re-checks every cited line's *content* on each run. Any
profile claim must be computed the same way, from the classifier's output at the revision the
profile binds.

**P4. The first conformant profile is named `driver_only`, v1.** A purpose-built narrow profile,
per D10 deliberately not carrying "DST" or "simulation" in its name: the real traced driver plus
the main-loop cursor, **empty extension install list**, covering no extension behaviour — exactly
the interim profile the ADR describes. Its definition records: no installed extensions (so the
coverage floor and per-hook disclosure hold vacuously), the D3 extension-effect fault class waived
with its condition (no effectful hook installed), the attribution-table reference, and **its
reachable clock set, stated by COMPUTING it**. The waiver list is settled at definition time against
A7's full table — the extension-effect class is waived by construction, and the approval-deadline
class is waived only if the profile's policy leaves its enabling condition off; either way each
waived class is named with its condition. It is the documented baseline profile for the Milestone C
name-adoption run. No shipped configuration can be the first profile: all fourteen install
`compaction_ai`, which calls `ai_step` and must be **omitted**, not installed-and-excluded (D1/D5).
A `compose`-bearing profile is the planned second claimant, in Milestone C.

***EXECUTED 2026-08-03, `dafe898`. An earlier revision of this paragraph said "a reachable clock set
of the four driver sites", and four is wrong at HEAD — it is SEVEN reachable: five routed and two
declared-unrouted.*** A12 routed a fifth site (`tool_phase.ail:342`) and A5 declared the two unrouted
ones explicitly. **This is P3's `4 / 12 / 13` defect recurring one artifact later, which is the
evidence that P3 names a standing hazard rather than a one-off.** `driver_only` therefore records no
count at all: `dst_driver_only.driver_only_routed_claim()` derives the partition from the table at
the revision the profile binds, and every assertion on it is a partition assertion rather than a
comparison against a literal. **Do not restate a number here.** The one thing the profile does record
is the declared-unrouted SET, because that is a claim about intent no analysis can recover, and the
validator checks it against the computed set in both directions.

**P5. The `stub_step.ail:170-173` stale comment** ("Returns both the step result and the updated
provider… thread next_provider") describes the pre-`89a1d67` contract and is deleted in WI-A2,
which rewrites that region anyway. The ADR's anchors into `stub_step.ail` are re-grounded in the
same change, filed as a normal amendment — not a review round.

**P6. `Ports.hooks_runtime` is removed.** *(Executed 2026-08-02, `4ad2c7a`, with cluster 1. It has
no work-item row, so the cluster map must name it — see C3 in
`NOTE-cluster-1-execution-report-and-plan-corrections.md`.)* D1 requires the plan to give it a demonstrated production
purpose or remove it. The survey found zero calls of the field repo-wide — only constructions. It
is deleted in the same edit wave as WI-A1 (both touch every construction site; separate commit).

## Work items

**How these are cut into executable sessions is recorded separately, in
`NOTE-execution-clustering-and-handoff-generation.md`** — the cluster map, what can run in parallel,
and how to generate the next handoff. Read it before writing one; it is derived from this plan's
dependency graph, so if the two disagree, this plan wins.

Milestone A is upstream-independent and starts now. Milestone B is **triggered**, not queued: it
begins the day a released AILANG ships the recorded-stream API, and interleaves with whatever A-item
is in flight. Milestone C depends on B.

**Sizing model, corrected by measurement at cluster 1** (`NOTE-cluster-1-execution-report-and-plan-corrections.md`):

- **Size by *sites touched*, not files and not days. This is the plan's sizing rule** — two
  independent confirmations (clusters 1 and 4), not a single observation. A1, A2 and A16 were
  estimated in days and measured in minutes, wrong by roughly two orders of magnitude and always in
  the same direction, because all three scaled M1 by *file* count. Site-scaling predicts both runs:
  cluster 1's 48 sites → ~10 min predicted against ~18 spent editing; cluster 4's 37 sites → ~13 min
  predicted for A9 against ~14 actual.
- **Size against the right population, which is not always the obvious one.** A9's five
  `emit_run_summary` call sites were the visible number; the load-bearing counts were **seven
  terminal returns and eight reachable termination reasons**. Sizing against the helper's callers
  would have missed two terminal paths outright (C2). **For an item that rewrites a *class* of
  things, count the class, not the helper.**
- **Sharpened by cluster 2, which falsified a prediction made from it and was confirmed by its own
  logic.** The handoff predicted A4 would come in *low* like A6's 16%, because classifier 1 is a
  working precedent. It came in at **58%** — the highest of any item. The predictor still holds,
  because what it actually tracks is **how much the specification leaves undetermined**: A6 was low
  because D5's rules were stated *and correct*; A4 was high because D5's rules were stated *and
  wrong*, so the item whose specification most needed re-derivation had the highest ratio. A
  precedent supplies **shape, not content** — classifier 1 gave A4 its fail-closed posture, `/tmp`
  refusal, target+selftest pair and output conventions, and none of its membership derivation.
- **The judgement ratio is predicted by whether the change introduces a value that did not
  previously exist** — not by "widening versus contract rewrite", which was the earlier reading and
  A12 falsified it from the inside. Bands: M1's additive 10%; port widenings **~19%**; contract
  rewrites **~27%**; A12 overall **29%**. But A12's *provider* class was a rename and came in at
  **13%**, below even the widening band, while every class that added a port shape and routed real
  call sites sat at **28–38%**. A rename converges mechanically; a new cursor forces a decision at
  every site that consumes it. Use ~30% for A10, A13, A14 and B2.
- **For a return-type change, count the destructuring sites before estimating — not the conceptual
  blast radius.** A12's typed tool contract was projected as "comparable to the five other classes
  combined" and came in at a third of that, the only over-estimate in three runs. The error was
  treating "return-class change" as inherently dear: `execute_allowed_tool_call` had **2** call
  sites and `ToolDispatchOutcome` **2** variants, so the real cost was six destructuring sites in
  two files. One `grep` for the function name answers it in ninety seconds. Cluster 4's return-class
  rewrite cost 26 sites because *its* class was seven terminal returns spread across the driver —
  the spread is the cost, not the return.
- ~~**This does not generalise to new-artifact work.** A7, A8, A10, A13, A14, A15 and B2 build
  things that do not exist; nothing here measures those and their estimates stand unrevised.~~
  **MEASURED 2026-08-02 by cluster 3 (A6, A7, A8). The hedge was right that it does not generalise,
  and wrong about the direction.** New-artifact sites are markedly CHEAPER per site than converge
  sites, not dearer — 7.6 / 5.9 / 19.8 sites per minute against cluster 1's 3.4. A converge site
  costs a compiler round-trip; an artifact row does not. Both new modules type-checked on the first
  `ailang check` and A8's 34-variant round-trip passed on the first run.

  **So sites/min is the wrong predictor for this class. Cost tracks the number of rows whose content
  must be DISCOVERED rather than TRANSCRIBED.** A7 and A8 are the controlled comparison: 68 sites in
  11.5 min against 158 sites in 8, because each of A7's eleven rows needed a recovery branch located
  and confirmed in the driver, while A8's thirty-four were transcription from one open projection
  function plus a classification judgement each.

  **Sizing rule for A13, A14 and B2:** count the rows requiring an independent source investigation
  and price those at roughly one minute each; price transcribed rows at negligible. The judgement
  BAND transfers unchanged — cluster 3 came in at **30% combined**, exactly the corrected
  predictor's high band, with A6 at 16% (rules fixed verbatim by D5) and A7 at 44% (two undetermined
  fields per row). **A7's shape is what to expect from A13 and A14.**
- The 14-minute discipline held for the reason M1 gave: **tooling first.** Cluster 1 wrote a
  parallel `ailang check` over the affected import closure (22 modules, 12 s) that surfaces one
  error per module instead of one per compile. Without it, convergence costs one round-trip per
  site. Budget the tool before the edits, every time.

### Milestone A — pre-repin (pinned v0.26.0)

**WI-A1. Widen `Ports.model_step`'s result with the emission log** (ADR handoff item 1; D1's
loss-channel rule). Behaviour-preserving: `emissions: []` at every construction site. Edit surface:
the `ports.ail` type, `ports_shape_probe`, 2 `stub_step.ail` adapters, 3 `long_qwen` sites, and the
3 result consumers (`dispatch_step`, `ext_ai_step`, `long_qwen:744`).
*Size:* ~~estimate by analogy — half a day~~ → **MEASURED: ~5.5 min, 6 files** (`e59acaa`,
2026-08-02). The estimate was wrong by ~2 orders of magnitude and the edit surface named 4 files, not
6 — it missed `fake_model`/`fake_ports` in `scripted_ports.ail`, a construction site reached through
`ports_shape_probe`. See `NOTE-cluster-1-execution-report-and-plan-corrections.md` (C1); size
remaining widenings by **sites touched**, not files or days.
*Acceptance evidence:* `make check_core` green; `make dst` targets pass unchanged; a
`Scripted`-provider test asserts the emission log is present and empty. Note per D1: **this item
does not enable WI-A2** — a successor cursor is not an emission.

**WI-A2. Fix the scripted cursor, main loop only** (handoff item 2; D1 cursor ownership; F6).
Depends on A1 (ADR-fixed order). The second, bidirectional widening of the same field — state in
and out — reviewed as a distinct change. Contents, all ADR-named: concrete `ProviderState` (shape
per P1) declared in `ports.ail`; **relocation of `ScriptedStep`** to `ports.ail` or below (both
required consumers close an `LDR002` cycle where it sits today); `ported_provider` returning an
initial-state pair; the sole persistent copy in **one explicit `C2LoopState` field**;
`scripted_ports_from_steps` consuming the threaded cursor instead of deriving position from
`assistant_count` — the arrangement D1 prohibits by name. Includes P5 (stale comment + anchor
amendment). Not behaviour-preserving; `ScriptedPortsState`/`scripted_model_next` is precedent, not
reusable code. Edit surface: `ports.ail`, `stub_step.ail`, `scripted_ports.ail`, `session.ail` (32
`provider:` occurrences bound the edit surface), `agent_loop_v2.ail`, import sites of
`ScriptedStep`, DST scripts.
*Size:* ~~estimate by analogy — 1–2 days~~ → **MEASURED: ~10 min, 9 files, 35 sites of which 6
needed judgement** (`6dd1bbe`, 2026-08-02). Tooling first, as specified, and that is why it held.
The "judgement band dominates" call was right: 17% here against M1's 10%. **Two of the six are sites
where both alternatives type-check and the wrong one silently reproduces F6** — see
`NOTE-cluster-1-execution-report-and-plan-corrections.md`, which WI-A12 must read before threading
`world_state` through the same successor literals.
*Acceptance evidence:* the F6 probe prints PASS and exits 0, and is promoted out of spike naming
into the `make dst` aggregate as a permanent regression test — landed as
`scripts/dst/scripted_cursor_probe.ail`, wired at `Makefile:86`;
`phase_c2_wiring_scenarios` at its full count (**19** once WI-A1 adds its emission-log scenario to that harness — an earlier revision said 18/18, which A1 necessarily moves); `check_core` green; `grep` finds no `assistant_count`-derived
script index. The extension model path is **not** fixed here and no work item pretends otherwise:
`ext_ai_step` (`session.ail:662`) discards state by ABI shape until Milestone B.

**WI-A3. File the two upstream reports — done 2026-08-02**, with this plan, via the
`ailang-feedback` skill's public MCP channel: (a) effect propagation through function-valued
record-field calls — the soundness gap D5's rowless-slot coverability leans on; minimal repro
verified at v0.26.0 (`check` clean, `EFFECT PERFORMED` at runtime, direct-call control correctly
rejected) — ticket `fb_74f53de3ae65854c`; (b) the `ailang iface` defects: `pure: true` alongside
nonempty `effects` on 12 `std/ai` exports (re-verified from `--json` output), the documented
`iface <module>` invocation failing (`cannot read file 'std/ai.ail'`), and `std/secret`'s `MOD010`
hard error auto-relaxing to a warning when run from a temp directory — ticket
`fb_d230853828108783`. Watch for replies when triaged.

**WI-A4. Build classifier 2** — the `ExtPorts` typed-call inventory (gate-mechanisms table). A
program, not a specification; the ADR fixes its contract (typed field-call inventory over `src` +
`packages`, fails closed on every alias, wrapper, re-export, or computed access it cannot resolve;
membership today exactly `ai_step`). Modeled on `tools/effect-inventory/derive.py` with a `make`
target and selftest.
*Size:* **estimate by analogy — an afternoon.** Basis: classifier 1, like for like.
*Acceptance evidence (per the gate table):* at HEAD it reports exactly the two known call sites and
zero unresolved occurrences; a synthetic alias/wrapper fixture is reported as unresolved →
fail-closed triage, not a pass; re-derivation wired into the repin checklist.

**WI-A5. Build the site-to-hook attribution table and its profile-load validation** (D4 clause 3) —
**in the same change as WI-A4**, per D4's producer clause. Initial rows: `ext/runtime.ail:190` →
`test_dummy`; `tool_phase.ail:287` → `scratchpad` (**A12 moved it; the plan cited `:222`, which is
now the guard's old address — corrected at implementation**); each with a named reviewer recorded, which is
the **stated exception** to the automated-gate promise until the interprocedural necessity
validator exists (that validator is *not* scheduled here; building it prematurely is exactly the
prose-refinement trap).
*Acceptance evidence:* validation rejects unknown hook ids, stale source-revision bindings, and
malformed rows; permits known-but-uninstalled hooks; the empty-intersection rule is exercised by a
test (a row whose hook set misses the profile's installs removes the site); the table's
`(source revision, content hash)` identity is what profiles reference. **Producer-side completeness
is evidence too, and row-shape checks do not supply it:** a fixture in which a
classifier-discovered core effect site appears in neither the attribution rows nor the explicit
unconditional-core set must be **rejected at profile load**. Without it a syntactically valid table
that silently omits a discovered site passes every other check — the fail-open D4 clause 3 exists
to close. **Scheduling prohibition honoured:** every routing-completeness claim in this plan
(A12's, C5's) names this item as a dependency.

**WI-A6. Build coverage-floor and disclosure validation** (D5; gate table, simplified — the
carve-out was deleted at acceptance, so this no longer depends on classifier 2). Profile-load code:
reject any installed extension with zero covered hooks; reject any installed extension with an
unconditionally-dispatched hook excluded; covered/excluded sets disjoint and exhausting all eight
slots; hook **ids**, not counts, in definition and run result.
*Acceptance evidence:* a fixture profile installing an all-excluded extension is rejected; the
rejection reason names the rule; `driver_only` (empty install list) passes vacuously.
*Size:* **MEASURED: ~5 min, 4 files (2 new), 38 sites of which 6 needed judgement** (`935bd46`,
2026-08-02). Landed as `make profile_coverage`, invoked by CI.

**SEVEN slots are unconditionally dispatched, not six, and this item is where D5's undercount
shows** (cluster 3, C1; D5 amended 2026-08-02). D5 says six unconditional plus one gated and leaves
the eighth unnamed. It is `on_describe_tools`, dispatched by an unconditional fold at
`tool_catalog.ail:114` which `live_ports` reaches on **every model step** — outside the
`ext/runtime.ail` the ADR surveyed. A profile excluding it must be rejected, and under the stated
six it would have loaded clean: both readings type-check and the wrong one is silent. **WI-A10 must
not re-derive the six from D5.**

**The acceptance line above names the weak fixture, and that is a correction worth carrying into
A10's and A13's acceptance lines.** "An all-excluded extension is rejected" is easy and shallow. The
fixture that separates this validator from a row-shape validator is the set-completeness one: a
disclosure whose two lists are disjoint, whose every id is real, and whose **entry count is
correct** — seven covered plus one excluded is eight — while one slot is classified nowhere. Only
counting per *slot* rather than per *entry* rejects it.

**WI-A7. Construct D3's fault catalogue** as a versioned, machine-readable artifact with a
fail-closed validator. New construction; the required classes, per-class fields (stable class id,
applicability condition, delivery constructor, named recovery-branch id, logical transition), and
the 007-D1.3 physical-fault tripwire are all fixed in D3 — the work is the artifact and validator,
not the design.
**A branch discrimination that can silently break belongs here too, and this item owns deciding it**
(cluster 4, C4). `decision_fail_reason` (`session.ail:1357`) separates max-steps from internal
failure by matching the literal message `"v2 loop: step budget exhausted"`, because
`step_machine.ail:93` and `:57` emit **the same `Internal` code** for the step-budget failure and
the approval-without-pending-call failure. Behaviour is exact today, but editing that string
silently reclassifies every max-steps run. Giving the step-budget `Fail` its own code fixes it and
**changes the `AIError` code callers see — a compatibility decision, which is why A9 did not take
it.** D3's catalogue names a recovery-branch id per class, so this is the decision's natural home:
decide it here, with the wire-compatibility consequence stated.

**One uncovered case cluster 1 surfaced belongs in this catalogue.** After A2, an extension-issued
`ai_step` against a `Scripted` provider is handed a fresh empty `ProviderState` and serves
`terminal_step()`, per D1's exclusion of the extension model path. **No test in the tree changed its
output**, which means nothing covers "an extension calls `ai_step` against a `Scripted` provider" —
and that is the concrete reason D1's rule (a conformant interim profile must exclude *every* hook an
`ai_step`-calling extension registers) currently has no instrument behind it.
*Acceptance evidence:* validator fails closed on a class row missing any field or naming an unknown
constructor; **and on a catalogue missing any required D3 class id** — set completeness, not only
row shape, because every downstream counter reads its ids from this artifact and therefore cannot
discover a class the artifact omits. An empty catalogue must fail. The two conditional classes
carry their waiving conditions; D11's class-reached and branch-reached counters read their ids from
it (exercised in WI-A14).
*Size:* **MEASURED: ~11.5 min, 7 files (2 new), 68 sites of which 30 needed judgement — 44%, the
highest ratio measured** (`a7d70b5`, 2026-08-02). Landed as `make fault_catalogue`, invoked by CI.
**A row here is TWO judgements, not one**: the recovery branch and the logical transition are both
undetermined by the source, which is why this item sits above the ~30% band while A6 sits below it.

**The max-steps decision, taken (cluster 3, C2).** The `Internal` code is **not** changed. A9
declined it as caller-visible; grounding it here found the consequence is larger — the driver's
`Fail` code is emitted as an `error` LEDGER EVENT (`ErrorEvent { code: e.code }`, `session.ail:2506`
and `:2576`) that the TypeScript TUI consumes, so a new code changes a wire event on every max-steps
run. That is a compatibility decision D3 does not own. The fragility is removed without it: the
literal lives once as `max_steps_discriminator_message()` in the catalogue, referenced by both the
`step_machine` `Fail` that emits it and the `session` matcher that reads it. Still open, stated in
both places: the discrimination is by message, not by type.

**Three findings the catalogue records rather than papers over** (cluster 3, C3/C4). D3's provider
protocol-inconsistent class names two forms and only the malformed-`arguments` one has a reachable
branch — nothing validates a `StepResult` for internal consistency anywhere. D3's approval-deadline
class has no clock-driven branch in production at all; the only no-response branch is channel
closure, which `resolve_approval` labels `"timeout"`. And `ExtPorts.ai_step` delivers no fault: it
is handed a fresh empty world, so a `Scripted` provider serves `terminal_step()` and the extension
is told the model answered — the one required class carrying `NoReachableBranch`, permitted because
it is conditional and only with a reason.

**WI-A8. Construct D6's event vocabulary** — the fifth recorded axis. New construction for all 34
`LedgerEvent` variants: variant, wire name, payload schema, logical/display-only classification;
fail-closed on an unclassified variant. `ledger_record_name` is not a seed and is not grown.

**The schema is `wire name = f(variant, payload)`, not `f(variant)`, and that is settled here rather
than discovered inside the item.** One variant of the 34 is payload-dependent: `StreamDelta`
projects to `reasoning_delta` or `thinking_delta` selected from `i.kind`
(`phase_vocab.ail:713`), both pinned by goldens (`:1139-1140`) and both recorded in the variant's
own trailing comment (`:631`). A one-name-per-variant artifact cannot represent it, so the
derive-from-the-type form is available only with a total projection function or an allowed-name
set — pick one in this item. It remains the preferred direction for the other 33, where drift stays
a compile error.
*Acceptance evidence:* load validation fails closed on a synthetic unclassified variant; **every one
of the 34 variants, and both `StreamDelta` branches, round-trip to the wire name the current
projection produces** — the existing goldens make this cheap and it is what would have caught the
schema error; the vocabulary version lands in the execution manifest (WI-A10) and failure record.
**Scheduling prohibition honoured:** no D7 parity invariant or acceptance row depending on the
classification is scheduled before this item completes — WI-A14's invariant set is explicitly split
on it.
*Size:* **MEASURED: ~8 min, 4 files (2 new), 158 sites of which 44 needed judgement** (`c873002`,
2026-08-02). Landed as `make event_vocabulary`, invoked by CI. 28 logical, 6 display-only.

**The classification is SEMANTIC, not a survey of what is appended today, and that choice was the
item's sharpest silent-wrong-answer site.** Only 13 of the 34 reach the returned trace at HEAD. A
survey-based classification declares 21 events display-only, validates cleanly, and makes D6.4's
parity obligation vacuous — blessing the exact gap it exists to close. The artifact keeps the survey
in a separate `reaches_trace_today` field, and `logical_variants_not_in_trace()` makes the distance
countable. **It is 15 today, and that is WI-A14's work list.**

**`DoneEvent` resisted the binary and is reported rather than decided** (cluster 3, C5; the
handoff's stop rule). D6.3 requires it to AGREE with the outcome and the `RunSummary` — an invariant
over its content, which display-only denies. But D6.1 requires the `RunSummary` to be the FINAL
record and the driver projects the `DoneEvent` after `c2_finalize` appends it, so D6.4's
"reaches the trace" and D6.1's final-record invariant cannot both hold by appending it where it is
emitted. The resolution (append before finalizing) is a change to a terminal path and therefore
**WI-A14's call against its invariant set**. Classified `Logical`, recorded in
`classification_findings()`, printed every run.

**Completeness cannot be a compile error on the pin, and the guards that stand in for it are the
item's real contribution.** A 35th variant forces an arm in `event_variant_id` (a total match) but
nothing forces a row or a sample, so it could be compile-clean and absent from the artifact. Three
`make` guards tie the lists to the TYPE DECLARATION rather than to each other:
`variants in LedgerEvent == rows == variants with a golden`. **The goldens do cover all 34** — an
obvious `grep '&& golden('` recount says 30 because the first golden in the block has no leading
`&&`; the tree was not wrong, the grep was (cluster 3, C7).

**WI-A9. Route every terminal path through one finalizer, type the termination reason, and build
D6's two result classes** (D6.1, D6.2, D6.6, D6.7). The spike proved `c2_finalize` (append **and**
emit) tractable without restructuring the driver; the starting count is zero everywhere. Replace
`finish_reason_str(r: int)` with a typed termination reason derived from the reachable terminal
returns, mapped exhaustively to wire `finish_reason`. **Also builds the result contract itself,
which an earlier revision left homeless:** the disjoint `SystemRun` / `HarnessFailure` shapes with
their D6-fixed fields — outcome, ledger trace, interaction log, replay metadata; and kind,
interaction position, actual request projection, partial ledger trace, replay metadata — plus
setup-failure-before-the-world-is-established as a typed `HarnessFailure` rather than a successful
empty trace.
*Size:* **MEASURED: ~14 min, 6 files (2 new), 26 sites of which 7 needed judgement** (`ff8d8e5`,
2026-08-02). Previously unsized.
*Acceptance evidence:* a trace-level test asserts exactly one `RunSummary` as the final record on
every enumerated terminal path; returned outcome, `DoneEvent`, and `RunSummary` agree; no integer
code survives at a terminal call site; a setup failure returns a typed `HarnessFailure` carrying its
partial evidence, and a raw capability bypass remains a non-zero run rather than a typed value —
D6.6 requires the two be distinguishable and they are tested as distinct. Landed as
`make terminal_trace`, invoked by CI.

**The terminal-path enumeration this item inherited was wrong in three ways, all found by building
it** (`NOTE-cluster-4-execution-report-and-plan-corrections.md`, C2/C3; ADR amended 2026-08-02):
**seven terminal returns, not five `emit_run_summary` call sites** — invalid history and the
internal approval failure emitted nothing at all, not even a projection, and an implementer working
from the five would have left both unfinalized. Among the reasons, **`dp7_rejected` is unreachable**
(no call site ever passed it; a DP7 rejection re-injects and terminates later), **unrecovered tool
failure is not a terminal path** at all (tool results feed back as messages), and
**system-prompt-empty is reachable and was missing**. An earlier revision of this line listed "tool
failure" among the paths to assert. Eight reachable reasons, all mapping onto the existing wire
strings, so no wire change was required.

**WI-A10. Build the profile definition and execution-manifest machinery, and define `driver_only`
v1** (D5; P4). Depends on A4, A5, A6, A7, A8 — **all of A6/A7/A8 landed 2026-08-02**; consume their
exports rather than re-deriving: `dst_profile_coverage.disclosure_from_ids` is the load-time parse
that fails closed on an unknown hook id, `dst_fault_catalogue.conditional_class_ids` and
`waiving_condition` supply P4's waiver list, and `dst_event_vocabulary.event_vocabulary_version()`
is the manifest's fifth axis. The definition references the attribution table, names its waived
fault classes by A7's stable class ids, and records the vocabulary version; load validation wires in
the floor/disclosure checks and both classifier outputs.

**Do not re-derive the unconditional-dispatch set from D5's prose: it is SEVEN slots, not six**
(cluster 3, C1; ADR D5 amended 2026-08-02). The eighth slot D5 originally left unaccounted is
`on_describe_tools`, dispatched by an unconditional fold in `tool_catalog.ail:114`
(`collect_ext_schemas`) reached from `live_ports` on **every model step** — outside the
`ext/runtime.ail` the ADR surveyed. **Under D5 as written, a profile excluding `on_describe_tools`
would have loaded clean and then failed closed on the first step.** A6 closed this with
`test_seven_slots_are_unconditional` and a `describe_tools_excluded` fixture; take the set from
A6's code, not from prose.

***EXECUTED 2026-08-03. Machinery `fd4f4bd`, profile `dafe898`; committed separately, as the item
required. Landed as `make profile_definition` and `make driver_only`, both in `dst` and in CI. Full
report: `NOTE-cluster-5-execution-report-and-plan-corrections.md`.***

*Size:* **MEASURED: ~30 min, 9 files (5 new), 77 sites of which 26 needed judgement — 34% combined,
but the combined number is misleading and should be read as two: the MACHINERY half is 58 sites /
8 judgement = 14% (below A6's 16%, so the three D5 amendments did settle what they appeared to),
and the `driver_only` half is 19 sites / 18 judgement = 95%, because a profile's CONTENT — which
adapter boundaries, which resource models — is discovered from the driver and is not a fact any
specification could have determined.** For any item shipping both machinery and an instance, report
the two ratios separately; a combined number reads as "the spec was vague" when the truth is "half of
this item was content".

**Composition is a FIFTH sizing model and S6 states it** (see the standing rules). Four round trips,
all loud parse errors with line numbers, and zero silent defects — so S5 would have priced this at
minutes and it took thirty. **Roughly half the time was GROUNDING: reading five artifacts' exports
and running two tools before a line could be written.** That is a cost S4 and S5 both assume away,
because both assume you already know the source you are working in; composition's whole job is to be
correct about somebody else's artifact.

**The three D5 definition fields this item had to ADD, because D5's ten are not decidable without
them** — carry these to A13 and C5: `unrouted_reachable_sites` (decision 1 below; D5 has no field
for a declared-unrouted site, so its all-or-nothing routing rule cannot distinguish a stated
containment from a silent gap), `scan_roots` (D5 obligation 2's roots, which the scan-root rule is
checked against), and `exercised_fault_classes` (D3 requires a non-exercised conditional class to be
NAMED waived; the complement is not recoverable from the waiver list alone, so an unstated waiver
would be indistinguishable from an exercised class). **Note also that D5's ten fields are TWELVE
record fields**: id/version is one D5 field and two records, and D5 field 2 — extension ids *and*
per-hook classifications — is two records, with field 9's disclosure a third. `make
profile_definition` guards the count at 15.

**Cluster 3's "four non-vacuous fields for an empty install list" is CONFIRMED and no fifth was
found.** All four carry real content in `driver_only`.

**Two decisions cluster 2 deliberately left to this item rather than deciding on its own authority**
(cluster 2, C4 and its handoff notes). ***Both are now TAKEN — see below for each.***

1. **Is a profile with an unrouted *reachable core* site conformant?** Two exist and both are
   declared rather than hidden: `session.ail:796` (ambient by design under S2, with the `Clock`
   poison probe as its instrument) and `stub_step.ail:146` (inside `live_ports`). D4's
   all-or-nothing routing rule points at non-conformant. **The live sub-question is whether
   `stub_step.ail:146` is in a deterministic profile's reachable set at all**, since `live_ports` is
   not the adapter a deterministic run uses — and D4's "profile-reachable" is installation-scoped,
   not execution-scoped, which is what makes the answer non-obvious. Decide it here; A5's
   declaration carries a `routed` flag per site precisely so the gap is stated rather than absent.

   ***DECIDED 2026-08-03: CONFORMANT, but only when the site is DECLARED and carries a named
   INSTRUMENT.*** Routing completeness is all-or-nothing over `{routed} ∪ {declared-and-
   instrumented}`. Undeclared is a rejection, a blank instrument is a rejection, and — the half that
   makes it a set check rather than a rubber stamp — **a declaration for a site that is no longer
   reachable-and-unrouted is also a rejection**, so a site that gets routed or moves cannot leave a
   stale declaration reading as if the gap were live.

   **The strict reading was rejected on three grounds, not one.** It makes conformance unachievable
   at HEAD *by construction* — `session.ail:796` cannot be routed on the pin at all, so no profile
   could ever load and D5's machinery would be vacuous until Milestone B's ABI major. It **inverts
   S2**, which deliberately chose the loud ambient read over the silent frozen cursor; a conformance
   rule punishing the loud option and rewarding the invisible one reverses the rule that produced
   the site. And it makes A5's `routed` flag dead — a flag no conformant profile may ever set to
   false states nothing.

   **The weaker reading is not a loophole because the instrument is real and already green.** `make
   world_state` runs the Clock poison PAIR: the deterministic entry point completes with `Clock`
   withheld (so it reaches neither site) and the live world dies with it withheld (so the first half
   is evidence of containment, not of nothing reading a clock). That is *stronger* than a routing
   claim — it demonstrates non-reach rather than asserting routing.

   **The sub-question is answered the same way rather than scoped away.** `stub_step.ail:146` STAYS
   in the reachable set. D4's profile-reachable is installation-scoped, so a site in a core module is
   in the set whether or not any run reaches it; carving it out on execution-scope grounds would put
   a fail-open exception into an installation-scoped rule and would have to be re-litigated for every
   future site. **One rule, two sites, no exceptions.**
2. **`driver_only`'s routed-set claim**, which cluster 6 routed and clusters 2 and 6 both declined to
   record. The table it needs now exists; compute the count from the classifier at the bound
   revision, per P3.

   ***DECIDED 2026-08-03: COMPUTED, and no count is recorded anywhere.*** At HEAD, 7 reachable = 5
   routed + 2 declared-unrouted. See the amendment under P4 for why the "four" this plan previously
   carried was already wrong.

**Consume A5 and A4 through their exports, not by re-deriving:**
`dst_attribution_table.validate_at_load(loading_against, discovered)` is the whole load-time gate in
one call; `table_identity()` is the `(source revision, content hash)` pair a profile records — and
**a table correction re-issues every referring profile**, as D4 states; `reachable_core_sites(installed)`
gives unconditional-core plus attributed-and-intersecting; `make ext_call_inventory --json` yields
`classifier_2_set`, `unrouted_fields`, `member_call_sites`, `unresolved` and the per-field rationale
for the manifest's derived-set records.

**Take A6's *set-completeness* fixture shape, not its easy one** (cluster 3, C8). This plan's A6
acceptance named "a fixture profile installing an all-excluded extension is rejected" — satisfiable
but weak. The fixture that separates a real validator from a row-shape validator is
`partial_disclosure`: both lists disjoint, every id a real slot, and **the correct total entry
count**, while one slot is classified nowhere. Only counting per *slot* rather than per *entry*
catches it. A10's and A13's acceptance lines should name that shape. **Also installs
runtime routing's fail-closed exclusion check** — dispatch reaching an excluded hook returns an
in-runner `HarnessFailure` (D5, D6.6), using A9's result types. Load-time rejection and A12's
capability probes do not implement this path; it is vacuous for `driver_only` and binding from C5
onward, and leaving it unbuilt would surface as a missing acceptance row at the gate.

**The profile *definition* has its own field list, distinct from the manifest's, and an earlier
revision enumerated only the manifest.** The definition records all ten D5 fields — id/version;
included extensions with per-hook classifications; **included and excluded provider/tool adapter and
parser boundaries**; **logical resource models**; **permitted diagnostic projections**; **forbidden
ambient effects/capabilities during execution**; waived D3 classes with conditions; the attribution
table reference; per-extension covered/excluded hook **ids**; and **omitted extensions with their
reason**. Four of those are *not* vacuous for an empty install list: the adapter/parser boundary
scopes D3's wire-parser exclusion, the diagnostic projections bound D1's collecting sink, the
forbidden-capability set is what A12's poison probes test against, and `driver_only` must name the
`compaction_ai` omission and its reason even though it installs nothing.
*Acceptance evidence:* `driver_only` loads clean and names its omission; a fixture profile
installing `compaction_ai` is rejected **at definition time** with the classifier-2 reason; **a
fixture definition missing any one required field is rejected at load, naming the field** — "loads
clean" alone cannot falsify a field the validator was never told to require; a fixture installing a
package whose AILANG source lies outside the recorded scan roots either extends the roots through
the resolved lock graph or **fails validation closed** (D5; the live shape is `ailang.toml:9`'s
registry-resolved `sunholo/logging`, exposure nil today); the manifest separately records D5's full
manifest list — source revision, toolchain, extension package and ABI versions, profile
id/version, event-vocabulary version, normalized configuration — plus both derived classifier sets
and the scan-root commit.

**Three of this item's guards are STRUCTURAL, and a structural guard that never fires is the exact
defect the item is about — so the acceptance line requires each to be MUTATION-TESTED.** All three
were, in session, and A13's line should carry the same requirement for its manifest consumption:
correcting a hashed field of the attribution table turns `make driver_only` red (D4's re-issue rule,
which `validate_at_load` alone cannot catch, because it fires at the SAME source revision); dropping
a member from the fixture's classifier-2 set turns `make profile_definition` red; and renaming
`driver_only`'s `compaction_ai` omission turns it red. **The third is the one that will earn its
keep** — the omission list is otherwise a guess frozen at authoring time, and with the guard the day
a second extension calls a state-threading seam the target goes red instead of the profile quietly
claiming coverage it does not have.

**The runtime exclusion check is BUILT and TESTED but its call site is not threaded into the dispatch
folds, and that is a scope judgement on the record rather than a missing acceptance row.**
`dst_profile.routing_violation_at` returns A9's `RoutingViolation` with the interaction position and
partial trace, and is tested for the violating case, the NON-violating case (a guard that failed
closed on everything would pass the first test and break every run), and the vacuous case. What it is
not is *called* from `fold_prompt_hooks` and friends: threading a profile there needs either a field
on `ExtRuntime` — which lives in the ABI package, so a Milestone B change — or a new parameter
through every fold, and at HEAD there is no consumer, since the load-time rules mean the only slot a
conformant profile may exclude is the one gated slot and no profile excludes it. A parameter with no
consumer is the dead-rider cost P2 rejects. **Its call site is WI-C5's** — A13 stages 2 and 3 both
established the profile and neither could give the check a consumer, for the structural reason
recorded at A13: replay sees interactions, and no interaction carries the hook id the check
discriminates on.

**WI-A11. The predicate documentation check** the ADR assigns to this plan. **It is an anchor-set
drift check, not a containment check, and that choice is forced rather than preferred:** the ADR
records that its six normative sites are "substantively aligned, **not word-identical** — the six
use six formulations" (`ADR:462-465`). A check requiring one canonical sentence to appear at all six
is therefore **red on the unmutated ADR at HEAD**, and the alternative — canonicalising the six —
is six ADR amendments this plan does not budget. Build instead: the six anchors named by location,
each with a content hash and a named reviewer who accepted that its formulation states the
predicate; the check fails when an anchor's text changes without a re-accepted hash, or when a
normative statement of the predicate appears outside the six. A small script with a `make` target,
CI-run.
*Acceptance evidence:* **the check is green on the unmutated ADR at HEAD** — the falsifiable half,
and the one a containment check would fail; *and* mutating one anchor in a scratch copy turns it
red. Both, because the second alone passes trivially while the first is broken.
*Size:* **MEASURED: ~35 min, 3 files (3 new), 13 passages of which 13 needed judgement**
(2026-08-03). Landed as `make predicate_anchors`, invoked by CI.
**The ADR asserted the count without the enumeration, and A11 could not be built against that.**
"the six" named no locations, and two defensible sixes existed — Status plus the four D1/D5 rule
statements plus the predicate definition, or Status, D1, the acceptance row and the handoff. A check
on either would have asserted a curation rather than verified one. D1 is amended (2026-08-03) to
enumerate the six by section, and `tools/predicate-anchors/anchors.json` records all **thirteen**
normative-region mentions — 6 anchors, 7 references — each with a named reviewer. Passages are
matched by **paragraph hash, not by line**: the ADR is amended often and a line-keyed check goes red
on every unrelated edit, which trains people to re-baseline without reading. Whitespace is collapsed
before hashing, so a reflow is not drift and any changed word is.

**WI-A12. Thread `world_state` through the driver, one effect class at a time** (D1). Depends on
A2; subsumes and deletes the interim `C2LoopState` cursor field in its first change, per D1.
Order within the item: provider (subsumption of A2's field), then the four driver clock sites
routed to the world clock (P3), then approval, then env reads, then runtime randomness; the typed
tool contract replaces stringly `tool_exec` in the same wave — it is D4's named first time-bearing
seam and D1 requires it anyway. **That contract is all three of D1's parts, not one:** a typed
`ToolCallEnvelope`, timeout/deadline information, **and a typed result/error** replacing
`tool_exec(string, string) -> string` (`ADR:606-609`; HEAD shape at `ports.ail:22`). An earlier
revision named only the envelope and deadline, under which a request-only widening would pass the
listed probes while leaving the return an undifferentiated string — weaker than D1 requires and
unable to carry D3's typed tool fault classes. Behaviour-preserving throughout: live adapters
delegate to today's code paths; `emissions`/state plumbing verified against `Scripted` providers.
Spike Q1 confirmed the threading and Q2 confirmed routing tractability (its count clause falsified
and superseded by the 13-site inventory); the spike's surgery is *not* imported — this is fresh
work at HEAD. **Also deletes `ported_provider`'s now-dead `history` parameter** (`_history` at
`session.ail`, six call sites): it existed only to compute the `base_assistant_count` that A2
retired, and D1 keeps the seam stable until `world_state` replaces it — which is this item (C5).

**The silent-freeze hazard is this item's defining risk, and cluster 1 measured it rather than
predicting it.** A2 threaded thirteen `C2LoopState` successor literals. The compiler forces the new
field to be *present* at all thirteen but accepts `st.provider_state` at every one — while six are
downstream of the dispatch call and must carry the successor. Cluster 1 verified the failure
empirically: flipping all six to the carry-forward form type-checks clean (`✓ No errors found!`) and
serves `[s0,s0,s0,…]` in **both** scenarios — a total freeze, worse than F6 itself. Only
`scripted_cursor_probe` catches it. **A12 threads more cursors through the same literals, at a
larger site count, for values with no equivalent instrument.**
*Therefore, binding:* **land an executable advancement assertion for each cursor before threading
it.** Not after. A cursor threaded without one is indistinguishable from a cursor frozen, in a tree
where every type-check passes.

**Cluster 4 sharpened this and the strengthening is not optional.** A9 found *four* silent-wrong
sites, and their shape is worse than cluster 1's: cluster 1's were successor literals where the
wrong value froze a cursor; A9's are **trace arguments where the wrong value yields a trace that
still passes its own invariant** — handing the finalizer `st.trace` instead of the trace carrying
the decision record silently drops the evidence the failure is about, while the one-`RunSummary`
assertion stays green. A12 now threads `world_state` through those same literals *and* through a
finalizer taking a trace argument. **The advancement assertion must therefore cover trace
completeness, not only cursor advancement**, or a dropped record satisfies every check A9 leaves
behind.
*Size:* ~~estimate — several days~~ → **MEASURED: ~92 min, 14 files, 119 sites of which 34 needed
judgement (29%)**, all six classes plus the typed tool contract (`2b938e1`…`3c2f4ab`, 2026-08-02).
Third confirmation of the sites-not-files model, and the first on an item the plan sized in days.
*Status:* **COMPLETE.** A13, A14 and A15 are unblocked.

**Two obligations this item could not discharge, recorded so their absence does not read as an
oversight.** (1) **The env class has no poison pair** — the driver's own six env reads are all
routed and `session.ail` has zero `getEnvOr` calls, but a deterministic run still dies with `Env`
withheld because `context_usage.ail`'s `resolve_context_limit` is `! {Env, FS}` and every env read in
it computes a path it then reads. Routing the env half alone would pass a poison probe while still
depending on ambient state — a defect manufactured deliberately. **A12's specified order contains no
filesystem class**, which is the gap; filed as
`.agent/issues/context-usage-env-reads-block-the-env-poison-probe.md` with three costed options, and
the Makefile says "DEFERRED, not skipped" out loud. (2) **`ExtPorts.clock_now` cannot be bridged on
this pin at all** — it is the only zero-argument port, zero-argument lambdas do not exist in
expression position, and partial application is unsupported, so no `() -> int` closure can carry the
world. It is bound to an **ambient read on purpose**: see the pattern below.
*Acceptance evidence per class:* existing targets green; the class's poison probe (capability
withheld) passes for the deterministic entry point and fails for the live world — the F3-corrected
per-run backstop; for the tool class, the typed contract carries ordinary success, typed
execution/non-zero error, wrong-call-id correlation, and completion-after-deadline through one
production adapter contract; after the clock class, `driver_only`'s routed-set claim becomes true and
is recorded — **computed, never written down** (P3), and depending additionally on A5 per D4's
scheduling prohibition. A10 measured it at 7 reachable = 5 routed + 2 declared-unrouted; an earlier
revision of this line said "4 sites", which is the stale-count defect P3 exists to stop.

**Staging correction, 2026-08-03.** A13 was handed off as five stages and the split had a gap: stage
2 was described as "discovery — record what the driver requests", which is only **half** of D2's
discovery. D2 is *seed-driven* — a generator **chooses**, the world **records** — and the choosing
half was never any stage's. It surfaced when stage 4's canary needed a generator to pin: nothing
draws from a seed, and `discovery_dst.ail:543-545` writes `seed: 0` on hand-authored scenarios.
Remaining stages are therefore **4 — the seeded generator; 5 — regression replay and D8's canary;
6 — D8's persistence obligations.**

**Stage 4 landed 2026-08-03 (`f77adf1`), and the correction above is confirmed rather than merely
asserted.** `src/core/dst_generator.ail` holds an explicit, seeded, state-threaded Lehmer PRNG — no
`std/rand`, and the module is in `src/core` so `make world_state`'s guard already covers it — with
`GeneratorState` riding in `WorldState` and `GeneratorBounds` moved down beside it. `make
seeded_generator` is wired into `dst`; `make dst` is exit 0 at 387 checks.

Two findings from it bind the remaining stages. **S8 above** is the first, and stage 5's canary is
its next customer. The second is a D2 reading no artifact contained: **an interleaved end-of-input
approval is an incompatible response**, because the world's approval cursor is a queue and a closed
stdin does not reopen. It was invisible to the structural validator, to `validate_bounds`, to the
reconstitution balance *in both directions*, to determinism and to seed sensitivity — and strict
replay refused it. Stage 3's fail-closed refusal path is what produced it, which is the second time
a stage's own guard has caught the *next* stage's defect.

**Stage 5 landed 2026-08-03 (`177d0cb`, `be8393c`).** Regression replay is D2's second mode with
**exactly two** of seven `ReplayMismatch` variants demoted; the correlation chain is one function
shared by both modes, so weakening it in regression mode reddens strict replay rather than passing
silently. D8's canary is **pure — it consults no driver** — because a canary pinned to a driver run
is red on every control-flow change, and a canary that cries wolf acquires the regeneration target
that would make it certify nothing. `make dst` is exit 0 at **403 checks**.

**Two findings from stage 5 bind what remains.** The first is **S8's complement** above: the canary
passed a mutation of what `note_bound` REPORTS until its trajectory was made to enter the bound
branches and its digest to fold every field rather than a count. The second is **site 22, and it is
D8's**: `seed_state` ADDS the id/version hash to the seed, so the two are interchangeable and —
measured across all 259 adjacent seed pairs, twice — **version "2" at seed *s* is byte-identical to
version "1" at seed *s+1***. A version bump is the same stream re-indexed, so **(id, version, seed)
is not a unique name for a program.** `check_seed_sensitivity`'s `versioned` row cannot see it: it
compares one seed across two versions and requires them to differ, and they do. It is pinned by a
characterization row that is *supposed to fail* when the defect is fixed. **Not repaired in stage 5**
because the fix remaps the whole stream and moves stage 4's searched seeds 9, 13 and 94 — each with
an asserted reason — requiring a 260-seed census re-sweep through the real driver. **Stage 6 must
either pay that or record the collision as a known property of the artifact store; it must not file
preserved artifacts under a key it believes to be unique.**

**Stage 6 landed 2026-08-03 (`6c4894e`, `e01a978`) and WI-A13 IS COMPLETE.** `make dst` exit 0 at
**466 checks** (403 at stage 5). Two commits: D8's secret handling, and the encoding with its
compatibility policy and store. Details in
`NOTE-cluster-12-execution-report-and-plan-corrections.md`; the four things that bind what remains:

- **Site 22 is decided and NOT resolved, and the reason is not cost.** Stage 6 recorded the collision
  and keyed on a content digest, leaving `seed_state` and stage 4's seeds 9/13/94 untouched, because
  **fixing `seed_state` would not make the triple a key**: D8 conditions reproduction on the recorded
  execution manifest as well, and (id, version, seed) omits it, so two runs at one triple under two
  manifests are two different programs today with or without site 22. The store therefore derives its
  PATH from the triple (a stable path is what makes a diffable encoding worth having) and its
  IDENTITY from `sha256Hex` of the exact bytes, and refuses by name to overwrite a path whose
  existing artifact differs. **The characterization row stays red-on-fix.** The residue is A15's: a
  corpus can now dedupe on `artifact_identity`, but the version axis stays decorative until
  `seed_state` changes.
- **A specimen must be CONSTRUCTED where the producer cannot reach the whole space.** Stage 4's
  sweep-and-filter cannot supply a compatibility specimen, because the generator provably cannot
  reach every shape the *schema* admits. **Sweep-and-filter selects among things that exist; it
  cannot cover a space the producer does not reach.** A15's corpora need both halves — a derived
  filter for selection, and a derived coverage requirement for construction.
- **A frozen compatibility artifact must assert DECODABILITY, not encoder stability.** Asserting
  `encode(specimen) == frozen_bytes` acquires exactly the regeneration target correction 1 of cluster
  11 warned about: a backward-compatible encoding change reddens it and the natural response destroys
  the specimen. The row asserts the frozen bytes still decode field by field, and reports an encoder
  difference as informational.
- **The triple is not the artifact's key and the manifest is the second, independent reason.** D8
  names a preserved failure by (id, version, seed) *and* conditions reproduction on the manifest;
  those two sentences are inconsistent as a naming scheme. A15's corpus keys on `artifact_identity`.

**Two scope items are explicitly NOT in stage 4 and are named here so they are not lost.** The
generator chooses no provider FAULT and no provider LATENCY, because `ScriptedStep` has neither an
error case nor an `advance_ms` — both are one field on that type away, restored on replay from
`TimedOutcome.advance_ms` exactly as the tool class's duration already is, with no codec change.
That widening is **WI-A14's D4 latency pair**, and A14 should expect it. `max_clock_advance_ms` is
nonetheless live, enforced and mutation-tested on the tool class. Separately,
**`max_resource_size` is the one declared bound with no mutation row** — it is bound to the
synthetic environment's entry count, which nothing this generator produces approaches; A14 should
either give it a resource that can grow or delete the bound.

**WI-A13. Build discovery and replay** (D2, D8). Depends on A7 (class ids), A9 (result types), A10
(manifest), A12 (world_state — **landed**). A12 also left a seam this item wants:
**`ScriptedWorld(WorldState)` on `StepProvider`**, added there so the approval class's assertion
could seed a world, and the natural entry point for replay. `ExecutionProgram`/`DiscoveryConfig` types, the seeded generator
with declared bounds, the pure structural validator, strict and regression replay modes, the
interaction log with causal identities and encounter ordinals. Exact type names are plan-level per
D2; semantics are fixed there and not re-litigated here. **Three D8 obligations ride here that an
earlier revision left homeless** — all normative, none deferrable the way shrinking is: **(1)
persistence safety** — programs carry synthetic values only, and environment maps and interaction
artifacts reject or redact secret-shaped/live credentials *before* persistence; **(2) the encoding
and compatibility policy** — a deterministic, diffable encoding (its selection is delegated to this
plan by the ADR's Non-goals) whose schema migrations either preserve old-program decoding or pin a
runner, never silently reinterpret; D6 binds the event vocabulary to the same rule, so it is
load-bearing twice.
**Determinism is the weakest available check and must not be this item's primary assurance.** Three
calibration runs have now produced ten sites where two alternatives type-check and the wrong one is
silent, and **the determinism axis caught none of them** — not cluster 1's frozen cursor, not
cluster 4's dropped trace record, and not one of A12's four. Every one was perfectly reproducible:
a frozen cursor serves the same wrong value twice, and an un-routed env read is reproducible when
the variable is unset in both runs. D7 asks for exactly "same seed twice → identical output" as the
discovery-contract invariant, and A13 will be tempted to lean on it because it feels like a proof of
correctness. **It is necessary and it is not sufficient. Carry an advancement or completeness
assertion beside it**, per the standing rule below.
**Consume A10 through its exports; this item is the second composition and inherits S6.** `driver_only()`
is the definition and `validate_driver_only(loading_against, discovered, calls, catalogue)` is the
whole load gate in one call; `driver_only_manifest(...)` builds the per-run manifest, with the
derived classifier sets passed as **arguments** because the tool derives them per run; and
`replay_metadata_of(manifest)` projects A9's `ReplayMetadata` *from* the manifest rather than
restating it — **use it, so a result cannot carry a profile id that disagrees with its manifest.**
The measured inventory and the classifier-2 call set are arguments everywhere: do not hardcode them,
and where a value must necessarily be copied, `tools/profile_definition/check_fixtures.py` is the
pattern for keeping the copy honest.

~~**This item is where the runtime exclusion check's call site lands**~~ — **MOVED TO WI-C5 by A13
stage 3, on a structural ground rather than a scheduling one.** `dst_profile.routing_violation_at(...)`
is built, tested for the violating, non-violating and vacuous cases, and returns `Option[DstResult]`
where `None` means proceed. Both A13 stages 2 and 3 established the profile and neither could give
the check a consumer, because **replay sees interactions and no interaction carries the value the
check discriminates on**: its parameters are `(definition, ext_id, hook_id, …)` and D2's
`ExtensionEffectIdentity(ext_id, class_id, call_id)` carries the extension id and the *fault class*
id, not a hook id. Its real consumer is the hook dispatch site — `src/core/ext/runtime.ail:279`,
`(h.on_tool_policy)(ctx, call)` — which is production driver code with no profile in scope, so
landing it is a change to the driver. Under `driver_only` it is vacuous regardless. **The call site
belongs where the non-vacuity does, which this plan already says is C5.**

*Acceptance evidence:* **every structural guard is mutation-tested, not asserted** (cluster 5, C5) —
a structural guard that never fires is precisely the defect these items exist to prevent, and A10
demonstrated all three of its guards going red under a deliberate mutation. Plus D7's
discovery-contract invariant — same manifest/profile/seed twice →
identical resolved program, interaction log, outcome, normalized trace; **plus a non-determinism
assertion — advancement or completeness — that would fail on a frozen cursor or a dropped record**;
a mismatch fixture returns typed `HarnessFailure` with position and projection; bounds violations
fail as generator errors;
D8's pinned generator canary exists per stable generator id and fails on a seed remap without a
generator-version bump; **a secret-shaped fixture is rejected or redacted before persistence**; and
**an old-schema program either decodes or fails closed with a pinned-runner pointer** — never
silently reinterpreted.
*Size:* ~~estimate — 1–2 weeks~~ → **MEASURED: six stages, 249 minutes of implementation windows
(34/43/35/60/36/41), 0 → 466 `make dst` checks** (`9c4d724`, `8b0d605`, `2d752da`, `f77adf1`,
`177d0cb`+`be8393c`, `6c4894e`+`e01a978`, 2026-08-03). **The largest Milestone A item, estimated in
weeks, took just over four hours.** The estimate's basis was right about the shape — "each small, the
set wide" — and wrong by two orders of magnitude about the scale, for the same reason every estimate
in this plan has been: it priced *artifacts* rather than *decisions*, and S6's binding count is what
tracks the cost.
*Status:* **COMPLETE (2026-08-03).** A14 and A15 are unblocked.

**What the staging got right, and it is the transferable part.** Every stage after the first landed
against a seam the previous one had left, and the *"stage N left the exact seam"* claim held four
clusters running. That is a consequence of each stage moving types **down** into the std-only tier
rather than importing up — `dst_interaction` in stage 2, `GeneratorBounds` in stage 4, `dst_secrets`
in stage 6 — because `src/core/ports.ail` cannot name `ExecutionManifest` without dragging the whole
`dst_profile` closure into the production driver's import graph. **The tier discipline is what made
the staging work.**

**What it got wrong, twice, and the two are the same mistake.** The item was cut as five stages and
re-cut to six mid-flight when the seeded generator was found to have fallen between stages 3 and 4
(cheap, because it was found before stage 4 started). Uncorrected: **stages 5 and 6 were each sized
as one stage and are each two independent pieces** — neither piece needed the other, and either could
have been a stage. **Sizing by obligations rather than by seams produced two stages out of six that
are really four.**

**And the ordering fact no single stage report states: the six were ordered by what each stage could
ASSERT, not by what it could build.** Discovery had to precede replay because replay grades itself
against a recorded log; the generator had to precede the canary because the canary pins the
generator's stream; persistence had to be last because a frozen specimen must contain every shape and
the shapes were not all defined until stage 5. **An item staged by dependency alone would have put
persistence second, where its specimen would have certified a third of the schema and nobody would
have known.**

**Obligations A13's stages 1–3 hand this item, each a finding rather than a preference:**

1. **D11's coverage counters must distinguish two kinds of evidence, not report one number.** The
   completeness assertion has an independent runtime witness for six of D2's seven request classes —
   the ledger trace for provider and tool (written by production code, owned by D6, so two authors
   record the same execution), the clock delta as the general one, message-derived counts for
   approval. **Environment reads have none**: `ports.env_get` is a keyed lookup, not a cursor, and no
   ledger event is emitted, so the recorder's own log would be the only record — the
   recorder-as-its-own-oracle shape. The mitigation is a **source-derived** expected key set (6 sites,
   7 keys), which is independent because it comes from the driver's source, and it must assert
   **multiplicity, not presence**: the driver reads `MOTOKO_TOOL_TIMEOUT_MS` once per native tool
   dispatch, so a recorder logging the first read of each key and dropping the rest looks complete.
   Report six classes with runtime evidence and one with provenance evidence.
2. **D3's `approval_deadline_exceeded` class is currently *unreachable* by a discovered program, and
   the counters must show it unreached rather than waived.** D2 gives `ExpectApproval` a deadline; the
   driver's approval channel carries none — `DenyAfterTimeout` is a decision, not a duration. This is
   a declared gap, not a solved problem.
3. **A13 stage 3's findings, all D2- or D8-shaped.**
   - **A recorded outcome must be sufficient to RE-SERVE the response**, or design note 3's refusal
     to put the queues on the program makes the program unreplayable. Stage 2 recorded the provider
     outcome as the prose alone, dropping the step's tool calls; `make discovery` was green against
     that recorder on all 48 checks, the wire witness, the structural validator and determinism,
     because discovery never reads the payload back. Same defect on the tool class: `ToolFailed`'s
     payload was its message, so the failure **code** was lost and a D3 fault class replayed as a
     success. Fixed in the recorded outcome, not on the program.
   - **D8's version gate and the actual compatibility boundary disagree, and this needs deciding.**
     A program discovered before that fix is undecodable by this build and fails closed with a named
     refusal — D8 behaving correctly. But `program_schema_version()` was **not** bumped, because no
     schema *field* changed; what changed is what a payload string contains. A payload encoding is
     part of the artifact's meaning even though it is not part of its shape.
   - **`ToolCorrelationMismatch` and `ToolDeadlineExceeded` are replayable but scenario-unreached.**
     Both travel through the same codec as `ToolFailed` and are covered by round-trip tests; reaching
     them in a scenario costs the surviving fixture's pairwise-distinct counts. D11's counters should
     show them *codec-covered, scenario-unreached* rather than reached or waived.
4. **Decide whether a coordinate-independent anchor for A5's table is worth building before the name
   gate.** A5 anchors attributed sites by line number. Stage 2 inserted lines above four of them,
   which re-measured the table, changed its content hash, and cascaded to five artifacts including a
   mandatory `driver_only` **v2 re-issue** — for a change in which *the claim did not move*: same
   sites, effects, routed flags and reviewers, only coordinates. Every guard fired loudly with an
   exact expectation-versus-actual, so the machinery worked; the cost is that a hash cannot tell a
   re-measurement from a correction, and a profile version is spent on a no-op. A symbol name plus a
   content digest of the enclosing function is the candidate. **A13 stage 3 weakens this case:** it
   edited `stub_step.ail` and paid nothing, by placing every insertion below the anchored line 161
   and widening the import list in place rather than by adding a line. One `sed -n '161p'` check
   costs seconds and avoids the whole cascade, so the cost is borne by authors who do not know the
   anchor exists — which is a documentation problem before it is a tooling one.

   **Cluster 10 separated the halves and the recommendation is now BUILD IT.** Stage 4 kept
   `stub_step.ail:161` intact by care — writing below the anchor, widening lines and import lists in
   place, and running `sed -n '161p'` after each edit, which caught one violation immediately. **But
   its four `session.ail` anchors moved anyway and no care avoids it:** a new `StepProvider` variant
   forces a new exhaustively-checked match arm in `ported_provider`, and *a match arm cannot be placed
   below the sites it precedes*. `driver_only` was re-issued at **v3** — the second re-issue in three
   stages, same claim, moved coordinates. So the avoidable half is now demonstrably avoided by a
   documented one-line check, and **what remains is structural, recurs once per port-shaped change,
   and costs a profile version bump each time.** Cluster 9 correctly weakened the case; the part care
   cannot reach restores it. Cost when it fires: ~6 files, ~6 minutes, all loud with the remedy stated
   at the point of failure.

**WI-A14. Implement the D7 invariant set, the D4 latency pair, and D11 run reporting.**
**COMPLETE 2026-08-04** (`00dbdb4`, `ea81e66`, `3dd8a82`) — three commits, one per mission piece;
`make dst` exit 0 at **551 checks** against 466 at the item's start. Cluster 13's report is
`NOTE-cluster-13-execution-report-and-plan-corrections.md`. **WI-A15 is unblocked.** Two assigned
sub-items are explicitly NOT done and are carried below with owners.

Depended on
A9, A13 (**COMPLETE 2026-08-03**); the parity-classification invariants
additionally depend on A8, **which landed 2026-08-02 — so this dependency is now satisfied and the
prohibition is discharged.**

**THREE CORRECTIONS THIS ITEM EARNED, and the first changes what A15 is blocked on.**

1. **D4's latency pair does NOT need the `ScriptedStep` widening, and this plan said it did** — in
   A13 stage 4's scope note, in item 2 below, and in cluster 10's correction 2. D4's pair needs a
   class with a **latency channel**, a **declared deadline** and a **comparison** between them; the
   **tool** class has had all three since WI-A12 (`ScriptedTool.duration_ms`,
   `ToolInvocation.timeout_ms` read through the env class at `tool_phase.ail:343`, `world_tool`'s
   guard). `scripts/dst/latency_pair_dst.ail` builds the pair on it and touches no world-input type.
   The **provider** class has none of the three, so widening `ScriptedStep` closes cluster 10's D2
   completeness gap and **not** D4's — a provider latency with no provider deadline has no
   completion-versus-timeout behaviour to demonstrate. **The two obligations are separable and only
   the first is met.**
2. **Provider FAULT and provider LATENCY are different fields, and this plan says "both one field
   away (`advance_ms`)".** Right for the latency, wrong for the fault: a provider fault is delivered
   on the `AIError` path, so `ScriptedStep` needs an **error case**, not an advance. Two fields, two
   changes. `dst_run_report.documented_coverage()` records the provider classes as
   `unreachable-until-change` with the corrected reason.
3. **D7 has TWELVE families and this item's sizing basis below says eleven.** `make invariants`
   now counts the declared `InvariantFamily` variants against `all_families()`, so the number is
   checkable rather than transcribed.

**What A14 did NOT do, both assigned, both unblocked, neither started.**

- **The `ScriptedStep` latency widening.** Not needed for D4 (correction 1) but still the open half
  of D2's "response, fault, and latency" on the provider class. **Predicted zero A5 anchor cost,
  source-derived rather than measured:** `session.ail` references `[ScriptedStep]` as a *type* at
  2656 and 2677 and **constructs none**, and adding a field to a record breaks only construction
  sites (P1's probe). 28 literal sites across `stub_step`, `ports`, `dst_replay`, `dst_generator`
  and eight scripts.
- **`max_resource_size`** — see item 3 below, now decided and sized.

**A14's own decisions, resolved.**

- **`DoneEvent`: RESOLVED.** `session.ail`'s `Finalize` arm appends it **before** `c2_finalize` and
  projects it **after**, unchanged. What makes this free is that **D6.4's obligation is PARITY, not
  a shared transition** — so D6.4, D6.1, D6.3 and D8's wire order all hold at once. The D6.4 gap is
  **14**, each remaining entry carrying its reason in `dst_invariants.parity_gap_reasons()`.
  `event_vocabulary_version` did **not** change, because `reaches_trace_today` is not one of D8's
  four versioned properties — which is the dividend of A8 keeping the survey out of the
  classification.
- **The coordinate-independent A5 anchor: DO NOT BUILD IT.** Fifth data point, and it runs against
  the case. A14 piece 1 edited `session.ail` **above** two anchors and paid **zero**, by sizing the
  replacement to the same line count. **The cascade correlates with adding a `StepProvider`
  VARIANT, not with editing near an anchor** — and a variant forces a match arm that no anchoring
  scheme can keep in place. Revisit only when an item must add a variant.

**Four things A13 hands this item, from cluster 12's close.**

1. **The CI replay affordance is this item's and it is now cheap.** D8 requires CI output to carry a
   copy-pasteable local replay command or artifact reference; A13 stage 6 built the store but assigned
   the reporting here, where the failure report is produced. `dst_persistence.artifact_path` gives the
   reference, `load_program` the other half of the command, and `persist_message` already prints the
   path and the identity. **What this item must NOT do is emit the digest alone.** D8's *"a digest
   without retained bytes is not sufficient for replay"* is enforced in the encoding — there is no
   representation of a program that is a reference to bytes elsewhere — and a report naming only a
   hash would reintroduce at the reporting layer exactly what the artifact refuses to represent.
2. **The three unreached fault classes are unreached in three DIFFERENT ways and D11's counters must
   not merge them.** `approval_deadline_exceeded` is *structurally* unreachable — D2 gives
   `ExpectApproval` a deadline and the driver's approval channel carries no duration, so this is a
   declared gap and not a solved problem. The provider fault class needs **an error case on
   `ScriptedStep`** — **not** the `advance_ms` latency field, and **not** D4's latency pair; all three
   were conflated by earlier revisions of this plan, by A14's handoff and by cluster 10, and cluster
   13 separated them (corrections 1 and 2). A provider *fault* is delivered on the `AIError` path and
   a provider *latency* is an advance: **two fields, two changes.** And **D4's pair needed neither** —
   it requires a class with a latency channel, a declared deadline **and** a comparison between them,
   and the **tool** class has had all three since WI-A12 (`ScriptedTool.duration_ms`,
   `ToolInvocation.timeout_ms`, `world_tool`'s guard), so A14 built the pair on that class touching no
   world-input type. A provider latency with no provider deadline has no
   completion-versus-timeout behaviour to demonstrate. `ToolCorrelationMismatch` and
   `ToolDeadlineExceeded` are *codec-covered, scenario-unreached*. Three counters, three meanings.
3. **`max_resource_size` — DECIDED by A14, and it is a generator-version item rather than a field
   edit.** Deleting it is a schema change, and specifically: `bounds` encodes as a five-field
   tab-separated line with `required_header_tags()` declaring arity 5, and both frozen specimens
   carry `bounds\t18\t19\t4096\t21\t22` — so dropping the field makes the decoder **refuse
   them**. But the decisive argument is not the cost: **D2 requires five declared bounds** and
   deleting the fourth makes the set 4 of 5, which is a specification regression wearing a cleanup's
   clothes. **So: keep the bound and rebind it to a resource that grows** — and that changes when
   `choose_environment`'s bounded alternative fires, which changes the draw stream, which is a
   **generator-version bump** with a canary re-pin. **Owner: A15**, which already re-pins seeds.
4. **Check whether the latency/fault widening adds a `StepProvider` VARIANT before assuming it is
   free.** A13 stages 3–6 all paid nothing on A5's anchors by writing below them and running
   `sed -n '161p'` after each edit; stage 2 and cluster 10 both paid a `driver_only` re-issue, and both
   because **a new variant forces a match arm that cannot sit below the sites it precedes.** Adding a
   *field* to `ScriptedStep` is free; adding a *case* is a profile version.

**A8 hands this item two things it must act on rather than inherit quietly** (cluster 3, C5 and the
classification split):

- **The D6.4 parity work list is `dst_event_vocabulary.logical_variants_not_in_trace()` — 15
  variants today.** A8 deliberately kept the survey fact (`reaches_trace_today`) in a field separate
  from the classification, because classifying by survey rather than by semantics would have declared
  21 events display-only and made D6.4's parity obligation **vacuous — blessing the exact gap it
  exists to close.** Only 13 of 34 reach the returned trace today. That number is the work, not the
  answer.
- **`DoneEvent`'s classification is A14's call to resolve, and A8 says so rather than deciding it.**
  D6.3 requires the returned outcome, `DoneEvent` and `RunSummary` to *agree* — an invariant over
  content, which display-only denies — while D6.1 requires `RunSummary` to be the **final** record,
  and the driver projects `DoneEvent` after `c2_finalize` appends it. Both cannot hold by appending
  it where it is emitted. The resolution (append before finalizing) is a change to a terminal path,
  which is this item's decision against its invariant set. A8 classified it `Logical` and recorded
  the tension in `classification_findings()`, printed every run. **Includes D4's latency-pair demonstration**, which an earlier revision left in WI-C4:
two replayable programs holding request and underlying completion result constant while changing
only generated latency/clock movement, producing the expected different completion-versus-timeout
result without an OS timeout. It is name-gate evidence but not upstream-dependent work — the
deadline seam (A12), generator and replay (A13) are all Milestone A — so leaving it in C made
Milestone A's boundary claim false. C4 runs the gate; it does not build the evidence.
*Acceptance evidence:* every D7 bullet has a runnable invariant; the latency pair demonstrates the
differing deadline outcome and both programs replay deterministically; a run report carries the
full D11 field list; class-reached vs branch-reached are separate counters read from A7's artifact;
a promoted failure travels as one artifact — exact program **with** its execution manifest — per
D11's promotion rule; **and the failure report carries a copy-pasteable local replay command or a
retained artifact reference** (D8), without which a CI failure is not reproducible by the person
reading it.
*Size:* **estimated 3–5 days; MEASURED at 78 minutes** on the git wall clock (handoff `0dd098f` to
`3dd8a82`), split 56 / 12 / 10 across pieces 1, 3 and 2. The estimate's basis said "eleven D7
invariant families" — twelve, per correction 3 — and treated the set's WIDTH as the cost. It is not:
the cost was three **discovered** bindings in piece 1 against two and zero in the others, and the
twelve families themselves were transcription once their shape was decided. **The estimate is off by
roughly two orders of magnitude and the reason is legible: it sized the artifact, and S6 says to
count the decisions.**

**WI-A15. Build D11's two corpora and their CI jobs.**
**COMPLETE 2026-08-04** (`ff54c0f`, `ee4311c`) — two commits, one per corpus; `make dst` exit 0 at
**700 checks** against 591 at the item's start, `make check_core` exit 0 at 51 modules. Cluster 14's
report is `NOTE-cluster-14-execution-report-and-plan-corrections.md`.

**CORRECTION 0, AND IT CHANGES WHAT HAPPENS NEXT: A15 IS NOT THE LAST ITEM IN MILESTONE A.** This
plan, the cluster map's prose and A15's own handoff all say it is. **A15 is the last item on the
CRITICAL PATH** (1 → 6 → 7 → 8 → 9). **WI-A17 is still open** — spawned by cluster 4, never assigned
a cluster, and recorded as unassigned in the cluster map's own last row for ten clusters. An item
that enters the plan sideways does not acquire a cluster and nothing in the process notices.
**Milestone A is one item short, and A17 is the item that checks whether inline tests run at all.**

**A17 LANDED 2026-08-04 (cluster 15), AND MILESTONE A IS COMPLETE.** Report:
`NOTE-cluster-15-execution-report-and-plan-corrections.md`. `make test_coverage` walks `src/core`
recursively and runs every inline test in it — **39 files, 370 tests**, against the 38 the item's own
handoff measured, because its `^\s+tests \[` grep cannot see `test "..."` blocks and missed
`prompts_test.ail` entirely. Three corrections worth carrying forward:

- **`ailang test` exits 0, and prints "All tests passed!", when every test in the file was SKIPPED.**
  `prompts_test.ail` reports `6 tests: 0 passed, 0 failed, 6 skipped` and exit 0. Ten tests under
  `src/core` are in that state at HEAD across three distinct skip classes, two of them upstream
  limitations on this pin. **Any future gate over `ailang test` must read a count, not `$?`.**
- **`requires` contracts auto-generate property tests**, so a file's test count can exceed anything a
  `tests`-shaped pattern can find.
- **Sites 32–34, all in the item's own guards and all caught by C5.** They sharpen S8's complement
  for guards built from SEQUENCED clauses: a control rejected by a later clause certifies nothing
  about an earlier one, and a control that must SURVIVE certifies nothing if the mechanism never
  reached it. Determinism has now caught 0 of 34.

**All seventeen work items are closed.** WI-A3 has no cluster-map row and needed none — it is the
upstream filing, done 2026-08-02 with this plan. The project is externally blocked on the upstream
recorded-stream API; `HANDOFF-post-upstream-recorded-stream-landing.md` holds the triggered graph.

**FOUR FURTHER CORRECTIONS THIS ITEM EARNED.**

1. **A CORPUS NEEDS TWO KEYS, and this plan's prescription fixes the other direction.** The plan says
   to key on `dst_persistence.artifact_identity` BECAUSE the (id, version, seed) triple aliases under
   site 22. Measured over 30 adjacent (v2, s) / (v1, s+1) pairs through the real driver: **29/29
   share a trajectory, 0/29 share an identity** — because `generator_version` is a field INSIDE the
   encoded bytes. Identity keying cannot merge site 22's aliases. It fixes the opposite direction —
   two different programs sharing one triple, which is D4's latency pair and the direction that
   LOSES a program. Coverage needs a second key over the interactions alone
   (`dst_corpus.trajectory_key`). **A plan can identify a defect correctly and prescribe a repair for
   the wrong direction of it.**
2. **D11's two counters have two DIFFERENT OBSERVERS and only one is in-process.** `NativeToolDenied`
   and `NativeToolResults` are both in `d64_gap_register()`, so branch-reached is observable ONLY on
   the wire, from production code that knows nothing about the interaction log. That is a stronger
   reason to keep the counters separate than the one D11 gives.
3. **The fixed bank reaches FOUR of nine required non-waived classes by search; a fifth is reachable
   only by CONSTRUCTION.** `provider_empty_terminal_response` — 0 of 260 seeds, 0
   `empty_stop_finalize` records on the wire across the whole sweep. Cluster 12's limit arriving
   where the plan predicted the SHAPE and not the INSTANCE (the plan named the provider fault class).
4. **`documented_coverage()` declared one class Reached that no seed reaches.** True by hand-authored
   scenarios elsewhere, false of every generated program — the exact hazard a declared register
   carries, and now recorded as the fact it has.

**`max_resource_size`: DEFERRED, and cluster 13's ground for assigning it here is wrong.** It is not
unlike D2's other four bounds — measured at HEAD, NO honest bound binds, and that is D2's specified
behaviour rather than a defect (`make seeded_generator` asserts zero generator failures on the honest
bounds). S8's complement is already discharged by `canary_bounds_tight`, which binds every limit for
every seed. What is genuinely weak is narrower: the quantity it reports has a static range of one
value. **It is a ONE-DRAW item, not a rebinding.** And cluster 13's sizing ground runs backwards:
A15 does not *re-pin* seeds, it *pins new ones from a sweep*, so a version bump does not share work
with the sweep — it serializes in front of it and makes every swept number provisional. **Owner: the
first item that touches the generator after the corpora exist** (in practice the B wave, which
re-sweeps anyway), and the corpora are the instrument that makes the new binding measurable.

*Historical scoping note.* An earlier revision
scheduled corpus *reporting* in A14 and left the corpora themselves unbuilt, which C4 would then
gate against. Build: the **blocking PR corpus** of fixed seeds and exact promoted regression
programs; the **scheduled rotating corpus** whose seed window changes deterministically; both CI
jobs, which are new construction — survey row 9 records the only workflow at HEAD is
`verify-extensions.yml` with no generated-trajectory axis. Select rotation, retention, and sharding
from measured CI cost here, together with each job's operator-accepted minimum seed count, per
D11's delegation to this plan.

**Select the corpora by SEARCH, not by authorship — stage 4 demonstrated the technique and it turned
a design decision into a query.** S7 requires a surviving fixture carrying every shape the
specification protects with no two of its quantities equal. Stage 4 satisfied that by sweeping 260
seeds through the generator and filtering on S7's own two obligations: **exactly two of 260
qualified.** Its pinned seeds (9 and 13 as an equal-census anti-count pair, 94 as an S7 survivor)
each have an *asserted* reason rather than a described one, so a change to the generator, to a
request-projection string, or to the driver's control flow moves them and fails loudly. **State the
corpus obligations as a filter, sweep, and pin the survivors** — authoring a corpus and hoping it
covers is the shape S7 exists to reject, and it does not scale to a rotating window.

**Stage 5 took the technique one step further and A15 should take that step too: DERIVE THE FILTER,
do not author it either.** The canary's pinned seeds were selected by a filter read straight off the
standing rules and the specification — S7 supplies pairwise distinctness, D8 supplies "a version bump
must remap both layers", and site 22 supplies the non-adjacency constraint. Of 260 seeds, **894774
triples qualified**, and the only judgement left was preferring a triple that walks the trajectory
extremes — the one axis a filter cannot express. Content judgement fell from stage 4's ~85% to ~25%
on that change alone. **When the filter is derived and the sweep is wide, the residual judgement
lives in one visible place instead of being spread across every pinned value** — which is exactly
what a rotating corpus needs, because the residual is the part a reviewer has to re-check when the
window moves.

**And stage 6 found the LIMIT of that technique, which this item needs before it starts.
Sweep-and-filter selects among things that exist; it cannot cover a space the producer does not
reach.** Stage 6's compatibility specimen had to carry every shape the *schema* admits, and the
generator provably cannot produce them all — the provider fault class and `approval_deadline_exceeded`
are both unreachable by a generated program. A swept specimen would have frozen exactly today's
reachable set and left the rest **absent**, which reads identically to unchanged (S8's complement).
The specimen is therefore **constructed against a DERIVED COVERAGE REQUIREMENT** — asserted over
`all_interaction_kinds()` and the status set rather than a list written at the assertion site — while
selection stays a derived filter. **A15 needs both halves: a derived filter for the seeds it can
sweep, and a derived coverage requirement for the classes no sweep will reach.** The fixed bank's
obligation is precisely of the second kind: D11 requires it to reach every required non-waived fault
class, and three of them are not reachable by search at all.

**Two more from stage 6, both about the artifact rather than the search.** (1) **Key the corpus on
`dst_persistence.artifact_identity`, not on (generator_id, generator_version, seed).** That triple is
not unique for two independent reasons — site 22, and the fact that D8 conditions reproduction on the
execution manifest, which the triple omits. A corpus holding (v1, seed 4) and (v2, seed 3) has one
program's worth of coverage while reporting two. (2) **A promoted counterexample is bytes, never a
digest reference.** D8 permits digest addressing and forbids a digest without retained bytes; the
encoding enforces it, and a corpus that stored references would reintroduce the gap at the corpus
layer.
*Acceptance evidence:* both jobs run and declare their minimums; the gate **fails** on a zero,
silently truncated, or below-minimum window (tested by forcing one); the fixed bank collectively
reaches every required non-waived fault class in A7's catalogue; a promoted counterexample enters
the fixed corpus with its manifest attached.
*Size:* ~~estimate — 2–4 days, dominated by CI cost measurement rather than code~~ →
**MEASURED: 58 minutes**, two commits (43 + 16), sixteen recorded bindings of which **seven were
discovered**. The CI cost measurement was **76 seconds of it** — 260 seeds through the real driver,
which is where `measured_ms_per_seed() = 292` comes from and what both jobs' minimums are arithmetic
over. Wrong in the same direction and for the same reason as every previous estimate: it sized the
artifact rather than counting the decisions. **The DISCOVERED count predicts for the fourth
consecutive measurement** — totals of 9 and 7 predict 43 : 33, discovered counts of 5 and 2 give
43 : 17, and the measured windows are 43 : 16.

**WI-A16. Wire the unrun driver coverage into `make` and CI — do this before A9 and A12.** No
dependencies; it is Makefile and workflow work, and it is sequenced first because it *protects* the
remaining driver items rather than following them. Cluster 1 found a live gap: **eight smoke scripts
that exercise the driver's full loop are in no `make` target and no CI job** —
`scripts/smoke_v2_{dp7_gate,pending_full_loop,compaction_full_loop,stream_parity,ext_fixture_parity,cost_budget_full_loop,compaction_chain}.ail`
and `smoke_phase_a_tool_parity.ail` — and **`src/core/test/scripted_ports.ail`'s six unit tests are
run by nothing**, since `check_core` covers `src/core/*.ail` only. Verified at HEAD: all nine have
zero references in the Makefile.

This is not hygiene. WI-A2 changed the contract every one of those eight depends on and nothing in
the repo would have run them; cluster 1 ran all eight by hand and all eight passed, but the next
driver change has no such guarantee. `smoke_v2_dp7_gate` is the **only** executable coverage of
`c2_after_dp7`, whose two successor literals A2 had to thread — precisely the code path A12's
silent-freeze hazard threatens.
*Acceptance evidence:* all nine run in a `make` target reachable from CI; the target fails when any
one of them fails (verified by breaking one deliberately); `scripted_ports.ail`'s unit tests are in
a named target.
*Size:* ~~estimate — under a day~~ → **MEASURED: ~9 min, 6 files, 11 sites of which 3 needed
judgement** (`61f38db`, 2026-08-02). Wrong in the same direction and for the same reason as cluster
1's estimates — sized as wiring by file count, when the real site count was 11, not the 2 this item
implied.

**The demonstration clause earned its keep, and that is a finding about how to write acceptance
evidence** (cluster 4, C1). "Verified by breaking one deliberately" could not be satisfied as
written: **four of the eight scripts had no failing exit path at all** —
`smoke_v2_{dp7_gate,pending_full_loop,compaction_full_loop,cost_budget_full_loop}` printed `✗` on a
failed assertion and exited **0**. Wiring them would have produced a target green regardless of
whether their assertions held. Measured, not inferred: with one assertion inverted, the script
exited 0 before the fix and 1 after. **Prefer acceptance clauses that must be demonstrated over
clauses that can be asserted** — an assertion here would have shipped the illusion of coverage.

**WI-A17. Sweep the second coverage axis: `ailang test`.** No dependencies; small. Cluster 4 found
that `check_core` type-checks `src/core/*.ail` but never *runs* their inline tests, so
`session.ail`'s 21 and `phase_vocab.ail`'s 27 — including the `RunSummary` goldens that hold the
wire strings — were executed by nothing. A16 put those two files in `make terminal_trace`, but the
general defect stands: **`ailang check` coverage and `ailang test` coverage are separate axes and
only the first has a target.** Cluster 1's C6/C7 did not catch it because they looked at
`src/core/test/` rather than `src/core/`. **And wire `scripts/probe_phase_vocab_sealed.ail` with INVERTED polarity — it is not broken.**
An earlier revision of this item said "fix or retire" it, at the wrong path (`scripts/dst/`), on the
grounds that it "fails at baseline with `IMP010` and stayed broken because it is in no target". Its
first line reads *"This probe is expected to FAIL with IMP010: phase_vocab's sealed constructors must
not be importable outside `src/core/phase_vocab.ail`"*, and project 004 records that failure as its
pass condition. **The compiler refusing the import IS the sealing assertion holding**; making it
compile inverts an invariant that has held since 004. Six cluster reports carried it as "pre-existing,
broken, in no target" and none checked what it asserts. The target must require the `IMP010` failure,
and treat a successful compile as the failure.
*Acceptance evidence:* every `.ail` file carrying inline tests is in a target CI invokes, verified
by an inventory that fails when a file with tests is unreferenced — not a hand-maintained list;
breaking one inline test turns CI red.
*Size:* **estimate — under a day**, at 27%: it is an inventory plus wiring, and the inventory is
the part that must not be hand-maintained.

### Milestone B — the repin (trigger: a released AILANG carrying the recorded-stream API)

**The triggered graph is explicit, because milestone order is not a dependency here.** Milestone B
starts whenever the release appears and interleaves with whatever A-item is in flight, so an item
that needs an A-item must say so or it can be started without it. **B1–B3 are one inseparable wave,
not three green states**: the new pin exposes the effect/ABI repairs and the `Message` migration
simultaneously, so B1 alone leaves the tree red. B1 is therefore **preparation-only**, and **WI-B4
is the wave's green integration gate.**

**WI-B1. Repin the toolchain — preparation-only, not independently green.** **Its gate is
"zero effect-row failures tree-wide", NOT `make check_core` exit 0.** An earlier revision — and A15's
handoff — put `check_core` in B1's definition of done while also calling B1 preparation-only, which
is a self-contradiction the executing session ran into: `check_core` dies in its `verify_extensions`
prerequisite, where all seven extensions fail on one `[Message]` literal missing `images`. **That is
WI-B3's work, so B1's own gate cannot depend on it.** The corrected gate is measurable, was met, and
does not reach across the wave. Update `ailang.toml`,
`scripts/install-prerequisites.sh:39`, and the Makefile guard together; **clear every
`.ailang/cache` in the tree before believing any diagnostic** (the phantom-type-error trap
reproduced across a version change). The two latent under-declarations (`walk_agents` `FS`,
omnigraph `register_with_config` `Process`) become hard errors and are fixed here.
*Size:* **measured, as one wave with B2/B3 — M2's 381 effect-row edits across 71 files**, almost
all mechanical via the compiler-driven repair loop. M2 is *not* allocated between B1 and B2: three
of its edits are the `motoko-ext-abi/types.ail` row corrections that belong to B2, and the rest are
the mechanical repairs here. Treat the 381 as the wave's total, not B1's.

**Measured at B1, and both numbers need their caveat carried or they will mislead.** The
`v0.26.0 → v0.33.0` sweep found **98 files newly red: 27 effect-row, 71 `images`.** B1 repaired
**66 effect-row lines across 46 files** and left zero effect-row failures reachable. **That is not a
refutation of M2's 381.** `ailang check` reports the *first* error per module and stops, so a sweep
surfaces a **frontier, not a total**, and this one terminated early by running into B3 rather than by
finishing. M2's 381 remains the wave's floor; B1's 66 is "the complete count of effect-row repairs
reachable on this pin."

**The same caveat governs the ABI, and it is S8's shape.** M2 predicted three ABI changes; B1 measured
**exactly one** — `ExtensionHooks.on_tool_handle` gains `Rand`. The other three hooks and
`ExtPorts.ai_step` sit in modules that never reached effect checking, because the `images` error
precedes it. **Absent reads identically to unchanged**, so the correct reading is *"one demanded so
far, the rest unmeasured until B3 lands"* — not *"M2 over-predicted"*. **D5's coverable surface
survived intact**, verified by diff rather than intent: the three rowless slots and `on_budget_plan`
are byte-identical.

**Two mechanisms B2 must budget for, both measured at B1.** Rows are **closed**, so widening an ABI
hook field does not permit narrower implementations — it *forces* every one to widen in lockstep,
which is why one field cost 46 sites. The four hook result types carry **191 rowed implementation
sites** (`ToolHandleDecision` 49, `PreStepDecision` 59, `ResponseInterceptDecision` 40,
`FinalizeDecision` 43); if all four gain both effects, that is the cascade's lower bound and it is how
381 becomes plausible. And the widening propagates **upward** — constructing a record whose field
holds an effect-declaring closure makes the *constructing* function perform that effect, so every
`make_hooks` and `register_with_config` above a widened hook widens too. Probed and confirmed **not**
a v0.33.0 regression: v0.26.0 does the same, and it is already-filed `fb_74f53de3ae65854c`.

**The third frontier, measured at B3 — and it is what B2 actually faces.** Clearing the `images`
wall did not make `check_core` green; **the wall moved.** All seven extensions still fail on one
identical line, but it is now `motoko_ext_compose.register_with_config` missing
`AI, Clock, IO, Process, Rand`. The 74 remaining failures split: **31** on that compose row, **21** on
`stub_step.live_ports` (missing `AI, Clock, Env, IO`), **7 + 1** on
`dst_replay.ail:998`'s `cannot unify record with unexpandable type constructor GeneratorBounds`,
**4** on a `compaction_ai` test, and **9** pre-existing. **65 newly reachable, 9 baseline.**

**The `GeneratorBounds` failures are a genuinely new species and nothing in this plan anticipates
them** — neither effect rows nor `images`. Note also that this is again a **frontier, not a total**:
three effect-row repairs and one type-constructor repair are all that is visible behind 65 files, so
**B1's "zero effect-row failures remain reachable" was true when written and is now superseded** —
correctly, and its own report predicted this shape.

**WI-B2 SPLITS IN TWO, and only the first half is forced** (recognised at B3's close). As written it
carries the ABI row corrections **and** the world-token widening that lifts D1's extension-model
exclusion. The second is a *design* change; the first is a *repair the compiler is demanding* and is
what stands between the tree and a green `check_core`. **B2a — settle the four `ExtensionHooks` rows,
then close the cascade they imply** — is handed off as
`HANDOFF-execute-b2a-abi-rows-and-cascade.md`. **B2b — the world-token widening plus the two
`ScriptedStep` widenings** — follows.

**B2a LANDED 2026-08-04 and the ABI answer is TWO rows, not four.** `ExtPorts.ai_step` gains
`Trace` (M2 predicted it; B1 could not confirm it) and `ExtensionHooks.on_pre_step` gains `Trace` as
a *consequence* — `Trace` reaches the extension surface only through `ai_step`, and the tree's only
two extension callers of it are both on the `on_pre_step` path. **`on_response_intercept` and
`on_solver_candidate` are measured NOT demanded.** So the cascade cost **62 sites, not 191**, and
M2's prediction was right about `ai_step += Trace` and wrong about the breadth. `make check_core` is
**green** — the first since the repin — and the tree is **218 pass / 17 fail**, above the v0.26.0
baseline of 213/22. **What remains of B2 is B2b alone: the world-token widening.** The row
corrections are done.

**B2b LANDED 2026-08-04, and the exclusion is lifted — but the conformance decision it forces is
DEFERRED to the plan, deliberately.** The token is an **opaque `ExtWorld = { token: Json }`**, and
that was *forced rather than preferred*: the ABI imports only `std/option` and `std/json`, and
`motoko_core` depends on the ABI, so **the ABI cannot name `WorldState`** — the dependency cannot
invert. Inlining fails because AILANG unifies records **structurally** but sums **nominally**
(probed), and `WorldState` transitively contains sums. Parametrising the ABI would rewrite two of
D5's three rowless slots. The inbound half rides on **`ExtCtx.world` as an additive field**, which is
the design's whole trick: **no hook's parameter list changed type, so all four un-widened slots are
byte-identical to HEAD** and `make profile_coverage` is green.

**`ai_step` left the classifier-2 set — 3 → 2, with zero member call sites — and the pin moved
deliberately.** `make ext_call_inventory_selftest` is green *with the pin moved*, which is the point.
**`make driver_only` now exits 2**, reporting that its manifest fixture records a classifier-2 set the
tool no longer derives. **That is the stop condition firing correctly and it is reported, not
repaired.**

**Two questions, answered separately as required.** Did `ai_step` stop being a classifier-2 caller?
**Yes, measured.** Is `compaction_ai` now installable? B2b said **"yes on the evidence"** — and that
reasoning is **correct against the classifier-2 objection and does not reach a second, independent
barrier.** Measured at HEAD: four of its **unconditionally-dispatched** slots are excludable-only
under D5's declared-row rule — `on_budget_plan` (constant but declares `{Env, FS}`) and
`on_response_intercept` / `on_solver_candidate` / `on_pre_step` (nine-effect rows) — and D5 forbids
installing an extension with *any* unconditionally-dispatched hook excluded. **So the omission
survives the death of its original reason, and the recorded reason is now false either way.** The one
genuinely open question is whether `on_pre_step` qualifies under D5's **criterion 2** — effectful only
through world-mediated ports with explicit world state returned — which B2b's widening may have made
true, and which the declared-row paragraph does not govern, since that paragraph constrains criterion
**1**. **WI-B4 decides it and records the reasoning.** The rest of B2b's finding stands: **yes on the
evidence** was — it calls no other
classifier-2 field, so the recorded reason for omitting it is void and D5's
unconditionally-dispatched objection has nothing left to bite on. **Re-issuing `driver_only` with
`compaction_ai` installed changes what the profile COVERS — a conformance claim, not a tidy-up — so
it is the plan's to take, with a profile version bump.**

**FOUR artifacts encode the old exclusion, not three.** The derived set, the pin
(`tools/ext_call_inventory/fixtures/expected.json` — note the `fixtures/` segment), `driver_only`'s
omission record, and **`dst_fault_catalogue.ail:299-333`**, whose `NoReachableBranch` still says
`session.ext_ai_step` "hands the port a FRESH EMPTY world". It no longer does. All four must agree
before the name gate.

**Two counts in this plan were wrong and are corrected by measurement.** The 191 rowed sites are
**206** — the grep counts only `<Type> ! {row}` annotations and misses **15 lambda-form** hook
assignments, three of which were B1's un-widened cascade sites, which is how the undercount
surfaced. And the cascade/latent split B2a was asked for is **262 cascade against 31 latent**: the
repin's genuinely *new* demand is small, and most of the diff is one ABI row's blast radius arriving
twice.

**B2a's defining constraint, and it is why the split matters:** the cascade's size is a function of
the ABI, so **the rows must be settled before anything below them is repaired, or the repair is done
twice.** Rows are closed, so widening a hook field forces every implementation to widen in lockstep —
B1's single field cost 46 sites, and the four hook result types carry **191 rowed implementation
sites** (`ToolHandleDecision` 49, `PreStepDecision` 59, `ResponseInterceptDecision` 40,
`FinalizeDecision` 43), counted at HEAD. B3 is what made the question answerable: M2 predicted all
four rows would gain `Rand` and `Trace`, B1 measured one, and the other three sat in modules that
never reached effect checking until the `images` wall fell.

**WI-B2. The extension-ABI major.** Depends on B1 (the pin that forces it) and **A12** — its larger
half threads the world token, and `world_state` is built there; if the trigger fires before A12,
the row corrections can proceed and the world-token widening cannot. One coordinated major,
containing both ADR-named parts: the
three `motoko-ext-abi/types.ail` row corrections (`ExtPorts.ai_step` gains `Trace`; the four
`ExtensionHooks` rows gain `Rand` and `Trace`) **and the world-token widening of `ExtPorts.ai_step`
plus the hook results and core dispatch results — the larger of the two** (Consequences). Lockstep
re-release of every extension package. This is what lifts D1's extension-model-path exclusion;
until it lands, an `ai_step`-calling extension is omitted from any conformant install list. Per D5,
the same major is where coverage can widen beyond the three rowless slots — either per-hook row
narrowing or the declared-versus-performed successor detector, both of which D5 assigns to this
major; WI-C5 depends on that part landing.
*Size:* **estimate — 1–2 weeks**, and it is the largest single item in the plan. Basis: the ADR
calls the world-token widening "the larger of the two" changes in this major, it touches
`ExtPorts.ai_step`, the hook results and core dispatch results together, and it forces a lockstep
re-release of **every** extension package. No measurement covers it; the mechanical row edits are
inside M2's 381, the widening is not.

**WI-B3. The `Message` migration** (vision/images field of the new pin). Depends on B1.
*Size:* **M1, measured — 14 minutes, 28 files, 69 additive sites, 7 judgement sites** — with its
two riders honoured: tooling first (the brace-balanced rewriter and fix loop are what made 14
minutes true), and the settled decision that Motoko's `Msg` and the ext-ABI `Msg` stay at four
fields, vision parts dropped at the seam.

**WI-B4 LANDED 2026-08-04 — MILESTONE B IS COMPLETE.** Whole-tree sweep **219 pass / 17 fail**
cache-cold, the 17 identical to B2a's member for member; `make check_core` exit 0 at 52 modules;
`make dst` exit 2 with **two** red targets, down from six, and neither this milestone's class. Four
targets went red→green. Four artifacts reconciled; `driver_only` **v3 → v4** (D4's re-derived
attribution table, D5/D8's `fault-catalogue/1 → /2`), with **no coverage movement**.

**The conformance answer: `compaction_ai` stays OMITTED, and the reason is now provable.** Criterion 2
is a **conjunction of three clauses** and B2b bought only the third — `next_state` is threaded, origin
was already tagged by `PreStepStage`, but `on_pre_step` declares `IO`, `FS`, `Net`, `Process`, which
are not world-mediated ports. **My handoff's open question is answered NO**: the declared-row rule is
scoped to *"per-hook classification"* full stop, not to criterion 1 — criterion 1 is its worked
example. And the independently sufficient argument: **admitting `on_pre_step` under criterion 2 IS the
claim that a hook performs less than it declares**, which D5 names a detector for and states is
explicitly unavailable.

**And the stronger result, which does not depend on `compaction_ai` at all:**
`ExtensionHooks.on_budget_plan` declares `! {Env, FS}` **in the ABI**, rows are closed so no
implementation can bind narrower, `Env`/`FS` are not world-mediated, `BudgetPatch` carries no
successor, and the slot is **unconditionally dispatched**. **Therefore no extension in the tree is
installable in a conformant profile, and `driver_only`'s empty install list is FORCED rather than
chosen** — now guarded by a mutation-tested check that prints its own vacuity.

**Two fail-open instruments were found certifying nothing, both exiting 0.** Classifier 1's self-test
reports `agree=0 disagree=0` on v0.33.0 — 46 stdlib modules now resolve by *textual fallback* because
`ailang iface` fails `MOD010` on every one — and `return 1 if disagree` called that a pass. **It is
now deliberately RED.** And `check_fixtures.py` check 3 re-derived the omission from
`member_call_sites`, which `ai_step` leaving the set emptied — so it passed by requiring nothing, at
the same commit that made the omission's reason false.

**WI-B4. Re-derive both classifiers on the new pin, and close the repin wave.** **A5's attribution anchors were ALREADY STALE at HEAD — nine of ten — and re-deriving them is
yours** (B2a). `make dst` reached `attribution_table` for the first time since the repin and it went
red on nine anchors that do not match at HEAD, *before any repin edit*: `tool_phase.ail:286` points at
a return-type annotation, `session.ail:807` at a comment, `stub_step.ail:161` at a `let` binding, and
`session.ail`'s 948/1053/2290/2400 at `else {` and three comments. Only `ext/runtime.ail:190` matches.
**The table drifted at some earlier point and nothing reported it, because `make dst` exited 2 long
before reaching the check** — absent reading identically to unchanged, one level above where B1 and
B3 found it. Six handoffs said "six items have paid zero this way"; that described a discipline which
had **already failed**. Choosing which site is "the" attributed site is a D4 judgement with other
consumers, so it belongs here rather than in a repair item.

**And make the anchor discipline mechanical rather than remembered.** B2a's repair tool asserts, on
every edit, that the file's **line count is unchanged** — because A5's anchors are line numbers and a
widening that collapses a multi-line signature moves every anchor below it. **It fired on
`session.ail`**, refusing a rewrite that would have gone 2962 → 2961 lines and silently moved anchors
2290 and 2400. Move that guard somewhere durable.

**Also re-run
B1's mutation loop, which could not complete — and B3's, which also could not.** Twenty files
carrying cascade sites were behind the `images` wall, and B3 adds **64 further `images` sites in
files that die on the third frontier before type checking**. Both sets are **unverified, which must
not read as verified**.

**`derive.py` FAILS OPEN and its failure is indistinguishable from a pass — B2b nearly shipped that
twice, and B4 must not trust its exit code.** After the widening the tool reported `ai_step unrouted`,
which is not a milder `member`: it means the field *bypasses the world protocol entirely* and removes
it from the gated set. The tool's own comment calls that class of answer "the single most expensive
bug in this tool's history." Two innocuous constructs caused it independently — **a nested paren in an
argument list** (its one-level call-forwarding regex cannot match it) and **an anonymous record return
type** (it takes the first non-effect-row `{` after a signature as the body, and got the return type).
Both were fixed at the source by hoisting a `let` and naming the type. **Any run that touches
`ext_ports_of` or its helpers must read the derived membership, not the exit status** — and the tool
needs a **positive control**: a fixture whose field *must* resolve to a seam and which fails loudly if
it stops. `control_resolved.ail` checks call-site resolution, not the bridge.

**B2a's closed-row argument is REFUTED for function-typed parameters — measured at B4 and
independently reproduced.** `ext/runtime.ail:545`'s
`chain_base_hook(id, pre: (ExtCtx, [Msg]) -> PreStepOutcome ! {…, Trace})` assigns `pre` straight into
`on_pre_step`, whose ABI row is **closed and includes `Trace`**. **Drop `Trace` from that
*parameter's* row and `ailang check` is green, and so is `make check_core`.** Two widths type-check,
in exactly the population declared structurally incapable of it. Seven sites share the shape and are
**deliberately held at the full row**, documented at the ABI beside `PreStepOutcome` so a tidy-up does
not narrow them. It is the declaration-side view of `fb_74f53de3ae65854c`, which D5 already records
from the performed side.

**Its companion claim is refuted too, in the opposite direction: a wider FUNCTION row does not
type-check fine — it propagates.** Widen `omnigraph.handle_branch` and its caller immediately demands
the effect and the file goes red. The effect checker is transitive through named helpers, so an
over-wide function row is silent only if every caller above it already declares the effect up to a
closed row that also declares it. That is why B4's loop returned **140 of 199 load-bearing**, and why
B1's three "known over-widenings" all read load-bearing at HEAD.

**So "no band exists" was too strong in both directions.** The 123 lockstep sites remain *mostly*
safe; the exception is the function-typed parameter.

~~**B2a narrows the target and says why.** Its 123 closed-row lockstep sites need no mutation loop:
a closed row admits exactly one width~~ — an implementation must *equal* its ABI field's row, not be a
subset or superset — so there is no band where two answers type-check, and both rows it changed were
mutation-tested and are load-bearing. **The loop belongs on the 180 function rows instead**, where a
*wider* row type-checks fine. That is the silent band B1's three known over-widenings live in
(`context_mode.ail:163`, `omnigraph.ail:79`, `:113`), so the population is known to contain the
defect. And note the mechanism: the compiler reports what a body needs *given its callees' declared
rows*, so **one over-wide callee propagates a too-wide answer to every caller above it**, and all of
them type-check.

**Probe from the module that FORCES the row, not from a convenient one.** B2a reproduced B1's
per-file blind spot deliberately: removing `Trace` from the `ai_step` rows reads **GREEN** probed from
`compaction_ai.ail`, which over-declares `Trace` independently, and **RED** probed from `session.ail`,
where the demand arises. A row mutation is only observable from the module that forces it, and
choosing the probe by convenience turns a load-bearing row into a false over-wide finding. Exactly one of them has a
narrow row (`compose.ail:756`) and is the remaining over-widening candidate; the other 41 full-row
sites are forced structurally by closed-row assignment. B1's loop also has a named structural blind
spot: it is per-file, so it cannot see a mutation whose breakage lands in a *different* file —
S8's unwalked-branch complement arriving inside a detector. Depends on B1, B2,
B3 (the source and ABI set is not final until they land), **A4** (classifier 2 must exist to be
re-derived) and **A10** (a manifest must exist to re-issue). Re-run `make effect_inventory`,
`effect_inventory_selftest`, `ext_call_inventory` and `ext_call_inventory_selftest` (A4's targets,
landed 2026-08-03); re-record both derived sets and the scan-root commit; re-issue `driver_only`'s
manifest. **Classifier 2 re-derives its own membership set from source on every run**, so the repin
step is to read the printed set and reconcile it against the recorded one, not to re-specify it —
and `ext_call_inventory_selftest`'s pinned membership block is what goes red if the ABI major (B2)
changes the answer. If the trigger fires before A4/A10, this
degrades to re-running classifier 1 alone and the rest waits — say so rather than letting it pass
silently.
*Acceptance evidence:* **this is the wave's green gate** — full compile and test suites pass on the
new pin, both classifiers report zero unresolved, and the re-issued manifest names the new
toolchain and ABI versions.

### Milestone C — post-upstream

**WI-C1. Adopt the recorded-stream API in the one `live_ports` closure.** Depends on **A1** (the
widened loss channel is what makes adoption observable — adopting first would carry an empty
emission log, D1's named trap) and **B4** (the integrated repin, not the bare B1). The blast radius
A1 bought: one closure.

**WI-C2. The direct positive integration probe** (D1's gate). Depends on C1 — it is the positive
proof of C1's adoption. Immediate projection, exact returned-log parity, success,
partial-stream-then-error, no duplicate delivery. Its passing is the substrate-gate evidence D1
requires; the forbidden delayed-projection fallback must not be selected silently.

**WI-C3. The streaming-trace parity invariant** (D6.4's named exception, checked explicitly).
Depends on C2 and A8.

**WI-C4. Run the name-adoption gate for `driver_only`** — depends on C2, C3, and all of
Milestone A. The acceptance-test table, answer by answer. **This item runs the gate; it builds no
evidence.** Every row's evidence is produced earlier — the latency pair in A14, corpus minimums in
A15, routing audit in A4/A5, hermeticity probes in A12, trace contract in A9 — and a row with no
earlier producer is a planning defect to fix here rather than an experiment to run at the gate. Only after every row holds does any target adopt the "DST"/"simulation"
name (D10). Until then, all new targets keep non-simulation working names.

**RUN AT WI-C4, 2026-08-05. THE VERDICT IS NO: seven rows of eleven hold.** Full row-by-row evidence
in `NOTE-c4-name-adoption-gate-verdict.md`; the four failing rows and their named producers are:

| Row | Why it fails | Producer the work needs |
|---|---|---|
| **Is the oracle complete?** | `d64_gap_register` holds **13** Logical variants that never reach the returned trace; **11 are `driver_only`-reachable** | Close the register: 2 terminal paths (unblocked), the 7-variant tool-dispatch fold, `ThinkingStreamEnd`, and 3 gated on an installable extension or a suspend trigger |
| **Do injected faults reach production recovery?** | 5 of 9 required non-waived classes reached; 4 registered as gaps, not waivers | An **error case on `ScriptedStep`** (closes 3) and a generator that emits malformed `tool_args` (closes 1). Neither externally blocked |
| **Is there actual search?** | Same 4 classes — the bank does not reach every required non-waived class | As above |
| **Is hermeticity enforced?** | The host-env class has **no poison pair**; `resolve_context_limit` reads 4 env vars ambiently at 6 driver sites | A **filesystem class in the world**, so the `Env` and `FS` halves route together. Routing env alone is refused on record |

**TWO ROWS PASS ONLY BECAUSE THE INSTALL LIST IS EMPTY, and per D10 a vacuous pass does not
transfer.** The boundary row's clauses over installed extensions are all vacuous (it passes on the
row's own visibility reading — a weak profile must be *visible* as weak, which `driver_only` is), and
`extension_effect_fault`'s waiver is purchased by installing nothing.

**THREE PLANNING DEFECTS THE GATE EXPOSED, and the first explains five items of misdirected effort:**

1. **The oracle row has NO SCHEDULED PRODUCER.** The text above asserts every row's evidence is
   produced earlier and lists A14, A15, A4/A5, A12, A9, C3 — but **no item was ever scheduled to
   close D6.4's general obligation.** C3 discharged the *named stream exception* only and said so.
   This is why every handoff from B4 to C5 tracked "can any extension be installed?" as the blocker:
   the row that actually blocks the name had no owner, so nothing reported on it. **The install is
   not the blocker and never was.**
2. **The host-env poison pair has no owner.** A12 was to produce the hermeticity probes and its
   specified order contains no filesystem class, so the env pair was deferrable at A12 with no later
   item picking it up. `world_state`'s Makefile note already called this a plan finding; it was never
   lifted into the plan.
**WI-D1, 2026-08-05 (`27951e7`, ~2h05m) — ROWS 4 AND 11 CLOSE. The unreachable register is EMPTY.**
The first item of this work list, scheduled by handoff because **the plan has nothing after Milestone
C**. All four classes are reached by search, `make corpus_pr` is green on the **wider** expected set —
nine classes, nothing subtracted — and every one is OBSERVED rather than declared. Verified at review:
9 expected classes, `provider_error_non_retryable` witnessed at seeds 3 and 36, `make anchors` 10/10
unmoved, `session.ail` 3213 lines before and after.

**Neither row closed by narrowing anything.** The register went to zero *before* the work started (S1)
and by classes being reached, not reclassified. `retryable` is **derived** from `error_code` with one
vocabulary in `dst_fault_catalogue` that `dst_generator` imports — chosen over a fifth `ScriptedStep`
field because that field would have had to travel in `encode_provider_outcome`, which is D8's
persisted artifact surface, and a field a replay cannot restore is a fault that replays as a
*different* fault while every count still balances.

**Two rows remain RED and the verdict is unchanged: rows 7 (oracle) and 10 (hermeticity). The name is
still refused** — nine consecutive items now.

**Caveat measured at review, and it sharpens rather than contradicts D1's M5.** D1 reports that a
driver ignoring `e.retryable` leaves the in-process suite "completely green" while only the wire gate
catches it. Reproduced: the **class-coverage rows do stay green** — `✓ every expected class was
OBSERVED (declared ⊆ observed)` with all nine validating — which is the substantive claim, because the
recorder derives the class from the code it served rather than from the branch the driver took. But
`make corpus_pr` still **exits 2**, on the bank *identity* pins, and aborts before reaching the leak
check at `Makefile:1129`. **So M5 is invisible to the rows that are supposed to see it and caught by a
pin that is only incidentally in its way** — which means the moment a legitimate change re-derives the
bank, nothing in-process catches it and the wire gate is the only thing left. That is the S16 reading,
and it is stronger than "the wire gate is not redundant."

**WI-D2, 2026-08-05 (`def464e`, ~46 min) — ROW 7 CLOSES. `d64_gap_register` goes 13 → 2**
(`ScratchpadResult`, `SessionSuspend`), Logical variants reaching the returned trace go 15 of 28 to
**26 of 28**, and `make ledger_parity` compares **17** variants wire-against-trace where C3's gate
compared one. The shape was the one predicted: the tool fold was **WI-A1's loss channel, second
instance** — `ToolDispatchOutcome` returned msgs and world and nothing about what was emitted, over a
multi-fire `emit` callback — and it was closed by A1's widen / C1's fill / C3's read, with
`c2_trace_wire_events` gaining a second caller rather than a new mechanism. **No `LedgerTrace` was
threaded into `tool_phase`; the driver remains the sole appender.** `driver_only` re-issued v7 → v8,
and **the anchor cascade was paid ONCE** — the first item to manage that — by tensing every comment
before deriving the anchors, which is S18 working as written.

**MY HANDOFF WAS WRONG ABOUT `ExtToolHandled`, and the evidence was in a file I had already
generated.** It reserved that variant as needing an installed extension and the `on_budget_plan` ABI
change. It needs neither — it is emitted whenever `dispatch_tool_handle` returns `Handled`, which any
hook can do. **Measured at 47 wire occurrences in a single `make dst` run**, and confirmed at review
against the `make dst` log I captured myself *three items earlier*: **exactly 47**, from
`long_qwen_compaction_dst.ail`, months of items before D2 touched anything. It was found only because
S15 required the survivors' reasons to be written as measurements, so the number had to be produced —
**the reason the item was about to write was the thing that disproved it.**

**ROW 10 IS NOW THE ONLY RED ROW**, and that sentence has not been true before in this project. Of
C4's eleven, ten hold. The name is still refused — a gate with one red row is a NO exactly as it was
with four — but it is **one item away**, and that item is named, sized and has a producer: a
**filesystem class in the world**, so `resolve_context_limit`'s `Env` and `FS` halves route together.
**Two of the ten passes stay VACUOUS in their installed-extension clauses**; closing row 10 makes the
gate green and does not make those non-vacuous, and per D10 a second profile earns them from scratch.

**WI-D3, 2026-08-05 (`14ba6f9`, ~2h05m) — ROW 10 CLOSES. C4's TABLE IS GREEN, ELEVEN OF ELEVEN.**
The world gained a filesystem class (`Ports.file_read`, a POINT READ), `resolve_context_limit` is
threaded at all **eight** call sites — the Makefile's deferral note said six — and the effect classes
with two-sided poison pairs go 3 → **5**. Verified at review: `make world_state` exit 0 with AI, Clock,
Env, FS and the tool contract each showing both halves, plus RNG's structural "no driver module
reaches `std/rand`".

**THE NAME IS STILL NOT ADOPTED, and D10's outstanding condition is the gate RE-RUN, not the ADR.**
007's taxonomy ADR is `Accepted 2026-07-26`, so the second condition has been satisfied for weeks.
**Eleven items have now declined the name.** And a green gate for `driver_only` is a green gate for
`driver_only`: two of the eleven passes stay **VACUOUS in their installed-extension clauses**, and per
D10 they transfer to no second profile.

**THE FIRST REGRESSION IN THE SERIES, and the item reports it rather than repairing it.**
`make seeded_generator` and `make corpus_pr` were green at HEAD and are red here — **one cause, not
two.** Routing `context_usage` puts the driver's config reads into the **recorded interaction log**:
each `resolve_context_limit` performs five env requests and the driver re-resolves a static value on
every loop arm, so a run carries 15–95 interactions no generator authored. Confirmed at review —
`seeded_generator` reports `the bounded run recorded 24 interactions against a declared budget of 6`
and `env_missing=50` dominating the S7 distinctness set. **This is not new breakage so much as newly
visible breakage:** `seeded_generator`'s bound is `log length <= 3 * max_interactions`, and **the `3 *`
was already absorbing driver overhead the generator never authored** — the check compares a GENERATOR
budget against a log the DRIVER also writes into. D3 widened the driver's share until the slack ran
out.

**A THIRD TARGET IS RED AND WI-D3'S REPORT DOES NOT MENTION IT — found at review, and it has a
counterexample to the report's own stated basis.** `make smoke_parity` was green through D2 and is red
at HEAD. `make dst` therefore has **five** red targets, not the two this series has carried:
`corpus_pr`, `seeded_generator`, **`smoke_parity`**, `test_coverage`, `test_coverage_selftest` — and
its ✓ rows fall **831 → 701**, because an aborting target stops producing rows rather than reporting
failures.

The chain, measured: `scripts/smoke_v2_compaction_full_loop.ail` drives the **scripted** world through
`run_v2_with_scripted_ports`, and its compaction behaviour depends on `test/tiny`'s context limit —
**which is in `.motoko/model-catalog.json` at 100.** With `resolve_context_limit` routed and the
fixture's `files` table empty, it now resolves to **0**, compaction never fires structurally, and the
parity harness's `grep -q '"type":"compaction_extension".*"note":"structural:'` finds **zero** where
it requires one. The adjacent `msg_count":14` assertion still passes, so the target fails on one
clause of two.

**D3's stated basis for believing this safe was:** *"The DST fixtures did not depend on the VALUES —
their models are absent from the catalogue and resolve to 0."* **`test/tiny` is not absent.** The
claim held for the fixtures checked and there was a fixture that was not checked. **This is S13's
lesson in a new place: `make world_state`, `discovery`, `strict_replay` and `compaction_dst` were all
run and all pass; the target that broke is one none of them covers.**

**The repair is named, measured and deliberately not taken:** `session_policy_init` already resolves
the limit into `policy.step.compaction.context_limit` and the four `c2_loop` sites recompute it;
reading the policy instead takes a run from 12–19 resolutions to one. A temporary assertion reported
**zero mismatches** across `world_state`, `discovery`, `strict_replay` and `compaction_dst`. It was
left because it is a change to the driver's call pattern rather than to its hermeticity, and landing a
behavioural refactor at the end of a long session without its assertion first (S1) is how this project
ships the defect it counts. **Owed as the next item's FIRST move, before the acceptance-table re-run,
because it moves the env census numbers D3 just pinned.**

**WI-D4, 2026-08-05 (~3h25m) — THE THREE TARGETS RESTORED.** `make dst` back to its two pre-existing
red targets, ✓ rows 745 → **845**, sweep 226/17 member-for-member, `corpus_pr`'s class rows green
**and printed**, and `resolve_context_limit` down from 8 sites on a run's path to **1**. The four
`c2_loop` re-resolves were licensed by **657 site executions across the whole gate with zero
mismatches** — D3 owed that measurement at three sites and D4 took it at all four. `driver_only`
re-issued v9 → **v10**.

**The successor audit the handoff demanded found exactly what it was written for.** Three of four
sites were not load-bearing; **`AwaitApproval` was** — `post_ctx` is `post` advanced past the
resolution, and `post` is `st` advanced past the **approval read**, so collapsing to `st` rather than
`post` type-checks and silently discards the approval cursor. **WI-D1's production defect in reverse,
in exactly the population the handoff named.** Not shipped; caught by reading the arm's own comment.

**And the conflation had THREE channels where the handoff named one — the second is the finding.**
See **S20**: the budget was the small one; the *salt* meant the driver's read count changed which
branch every generated choice took.

**Two corrections to this reviewer's own analysis, both verified:** `corpus_pr`'s class rows were
**red, not missing** (see S19's extension — I grepped a `make` transcript that truncates on failure),
and the conflation was three channels rather than one. The first matters most: **"unevidenced"
understated "failing"**, and the real state was a required fault class that no member of D11's
blocking bank reached.

**WI-D5, 2026-08-06 (~25 min) — THE TABLE IS RE-RUN AT ELEVEN OF ELEVEN AND THE NAME IS ADOPTED.**
The first run of the full table since C4. `make dst` exit 2 with **only** `test_coverage` and
`test_coverage_selftest` (pre-existing since B2a), **845 ✓ rows** — identical to D4's, same
methodology — and a cache-cold sweep at **226/17, member for member**. The baseline profile is
**`driver_only/10` under manifest `driver_only/3`**, named per D10's requirement that every report
name the profile. Condition 2 (007's taxonomy ADR) confirmed `Accepted 2026-07-26`. Adoption is
recorded in `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md` with the three
superseded claims **restated with their date rather than deleted** (S15). **Nothing was renamed** —
007 grandfathers the existing `dst` identifiers and D10's adoption permits the label without
requiring churn.

**THE VERDICT CARRIES A MANDATORY CAVEAT: the axis's extension-model coverage is ZERO, and it is
STRUCTURAL.** The empty install list is forced while `on_budget_plan` declares `! {Env, FS}` and
returns a successor-free `BudgetPatch`. **Four rows lean on that emptiness, not two** — and the
fourth is the item's finding: row 3 passes **vacuously**; row 4's `extension_effect_fault` waiver and
**row 7's `ScratchpadResult` exemption** are bought by it; row 5's pass is real but does not transfer.
**Row 7's leaning is NEW and appeared because D2 succeeded** — at C4 the register's thirteen entries
made the profile's emptiness irrelevant there, and closing eleven of them left a residue in which one
of two survivors is purchased by the empty install list. **Closing a row can concentrate a vacuity
rather than remove it**, and nothing in these rules tracks that.

**One row passes on a stated reading, reported rather than buried.** Row 7's third conjunct is
literally false for two Logical variants; it passes on WI-D2's recorded reading — *emissions that
OCCUR reach the trace* — backed by 17 variants compared wire-against-trace out of process. **This is
not the narrowing C4 forbade** (no reclassification, no shrunk profile claim; D2 closed the row by
appending eleven variants). But it is the table's single interpretive dependency: reject the reading
and row 7 is red and the verdict is NO. **At C4 the row failed under every reading, which is why
nobody had to adjudicate it then.**

**THE TABLE AS OF WI-D4 WAS UNOBSTRUCTED AND WAS NOT CLAIMED.** Rows 4 and 11's evidence is green and
printed, rows 7 and 10 were green throughout, and nothing in D4 re-ran the table — that was D5's job.
Three things it must not inherit as settled: **the env census numbers moved 12/12/12/19/8 → 1 across
the board**, the profile is **v10** so any artifact naming v9 is stale, and **two of the eleven passes
remain vacuous** in their installed-extension clauses. **Twelve items have now declined the name.**

3. **This entry did not say what to do with a NO.** It describes running the table and adopting the
   name. "Expect NO" had to arrive by handoff rather than by plan. **A gate that reports NO with a
   work list is the successful outcome, not the failed one.**
4. **AND IT STILL DOES NOT SAY WHAT A YES MEANS.** Defect 3 was answered; its mirror was not.
   Nothing in this entry says that adoption is a **documentation act with a mandatory caveat** rather
   than a rename — that 007 grandfathers the existing identifiers, that D10's adoption permits the
   label without requiring churn, and that the verdict must carry what the label does *not* assert.
   All of that had to arrive by handoff at WI-D5, which is the same failure mode as defect 3 one
   branch over.
5. **"WHAT THE LABEL DOES NOT ASSERT" IS PROSE, AND IT IS NOW LOAD-BEARING FOR EVERY FUTURE REPORT.**
   The zero-extension-coverage sentence lives in a note and a design document — **exactly the class
   S15 says gets quoted forward and re-dated**, and this project has carried that class in five
   consecutive items. Everything it asserts is already computed: the install list is empty, the
   emptiness is forced by `on_budget_plan`'s row, and `make driver_only` guards both. **A row that
   printed the caveat as gate output would make it impossible to report a green table without it.**

**WI-D6, 2026-08-06 (~66 min) — THE INSTALL IS UNBLOCKED. ROUTE A. COVERAGE DID NOT MOVE.**
`ExtensionHooks.on_budget_plan` went from the ABI's closed `! {Env, FS}` to **no row at all**, at 48
binding sites across 38 files, and the cascade was **two lines** the compiler found. Route B was not
needed: criterion 1 is satisfied outright, so no successor field was added. `driver_only` **v10 →
v11** — and unlike D2/D3/D4's re-measurements, **this bump changes a claim**: `compaction_ai`'s
omission reason no longer says the omission is forced by the ABI.

**Verified at review: a budget hook that reads `Env` is now REJECTED** —
`incompatible closed rows: r1 has extra labels [Env], r2 has extra labels []`. **A performing body in
this slot is not merely absent, it is unwritable**, so re-widening is a deliberate act rather than a
drift.

**The measurement is the item's durable output and its finding is the confound.** Fifteen bindings
measured declared-against-performed, **zero blocking** — but **nine of fifteen `register_with_config`
implementations read `Env` before any hook is dispatched**, so the naive arm scores nine extensions as
"the hook performs `Env`", which is a false positive *in the direction that refuses Route A*. Measured
before the arms were written, which is why every runtime subject is a register-only / dispatch pair
and `CONFOUNDED` is a first-class outcome.

**B4's guard fired on the OPPOSITE change from the one it anticipated.** It was written to go red "the
day WI-C5 widens `on_budget_plan`"; D6 *narrowed* it and the guard fired anyway, on the same clause,
because **it pinned the fact rather than the direction.** That is the standard for a pin in this
project.

**S21's first deliberate application, and the count HELD at four.** None of the four leaning rows
closed — `driver_only` still installs nothing by its own definition — but **every reason
concentrated**: row 3's vacuity now rests on a list this profile *chooses* not to fill; row 4's
waiver rested on two reasons and now rests on one; rows 5 and 7 are unchanged in words and now
actionable. A fifth site concentrated the same way outside the table (`dst_hook_guard`'s
unreachability). **The rule working is the count holding, not the count moving.**

**D5's caveat is updated in both places, dated rather than deleted.** *"Structural rather than
incidental"* and the whole **forced** clause are **FALSE from 2026-08-06**. Still true and still
mandatory: **the axis's extension-model coverage is ZERO.** **The emptiness moved from FORCED to
CHOSEN, which is a WEAKER claim than D5's, not a stronger one** — a chosen emptiness covers exactly as
much as a forced one. The gate now prints it, which partially discharges D5's planning defect 5.

**D5 called this "the one item that would make the name transfer." It was necessary and not
sufficient, and the name did not transfer.** WI-C5 spends it.

**CORRECTION, APPLIED AT REVIEW: D6 DID NOT UNBLOCK THE INSTALL, AND IT CONTRADICTED ITSELF.** Its
report and its design-document edit both state *"an extension is now installable in a conformant
profile."* **It is not.** `on_budget_plan` was **one of four barriers**; three remain and all three
are **unconditionally dispatched** — verified in `dst_profile_coverage.hook_dispatch`: `OnPreStep`,
`OnResponseIntercept` and `OnSolverCandidate` are `Unconditional`, and only `OnToolHandle` is `Gated`.
`on_pre_step` declares `IO`, `FS`, `Net`, `Process`, none world-mediated; the other two declare nine
effects while returning constants. Under D5 an extension may not install with any unconditional hook
excluded, **so no extension is installable.**

**`dst_driver_only.ail`'s own omission reason says this correctly** — *"The three other former
barriers stand and are unaffected"* — **so the two artifacts D6 wrote in the same item disagree, and
the profile is right.** The design document was corrected at review; the report's summary stands as
written, per S15, since it is a historical record.

**The lesson is S22's, one level up.** D6 derived its *subject* list from a producer and asserted the
agreement — exactly right — and then took its *barrier* count from prose. **A scope claim and a
completeness claim are the same kind of claim**, and the one that was checked held while the one that
was not did not. **Nothing went red**: the profile and the design document can disagree indefinitely,
because no gate compares them.

**What D6 delivered, stated at its true size: one barrier of four removed, and the argument that
could remove the other three.** That is a real result.

**WI-D10, 2026-08-06 (45 min) — BOTH AMENDMENTS LANDED. Zero source files changed.** B applied
first, its range extended `:1398-1418` → `:1398-1429` because the draft's own consequence list reaches
two passages below `:1418` and stopping short would have left the ADR contradicting its correction two
paragraphs later. A inserted with all four conditions. **The gate-mechanism table gained no row and
the deferred count is untouched at three** — verified at review — because that edit is both acceptance
reviewers' jointly.

**A-2 was SPLIT rather than signed or dropped**, which is better than the handoff's binary: the
*measurement* that falsifies the sufficiency claim is stated in full (`compose` 17 modules,
`context_mode` 7, both DIRTY on imports where Route B routes only calls), and the *cost estimate*
— "materially more work" — is left out and recorded as owed to WI-C5's owner. **No cost claim in the
ADR now lacks an owner.**

**A-1's probe found the proposed fallback works and FAILS OPEN on 44 of 465 symbols** — 39 `export
func` with no row at all, 5 with an effect *variable* — which for a fail-closed instrument is the
wrong direction, and `std/json.jo` is among them, imported by three of the four extensions A-3's yield
rests on. **Two strictly better producers existed and nobody had looked:** the compiler's own cached
`iface.json` (`ailang.iface/v1`, 23 of 46 stdlib modules, per-symbol, distinguishing an effect
*variable* from concrete labels) and `ailang iface`'s own stdout, which already emits
`funcs[].effects` and **is blocked only by MOD010's path rule, not by a missing capability**. So
classifier 3's symbol-granular property is buildable and the amendment does not rest on the broken
route.

**THE ITEM REFUSED THIS HANDOFF'S CENTRAL INSTRUCTION AND WAS RIGHT TO** — see S15's refusal case.
**And the handoff contained the very defect it was written about:** it cited `:2113` for the
"None of the three" sentence, which was at `:2115`; `:2113` was the coverage-floor row. Verified
against the pre-edit file at review.

**WI-D17, 2026-08-08 (~1h05m) — THE FILESYSTEM WRITE CLASS, AND THE REMOVE CLASS WITH IT.**
Verified at review: `Ports` **6 fields → 8** (`file_write: (WorldState, string, string) -> FileMutation
! {FS}`, `file_remove: (WorldState, string) -> FileMutation ! {FS}`, `FileMutation` =
`{ ok, error, next_state }`); `IdentityBody` **7 constructors → 9**; `ExtPorts` **7 fields**, both new
rows deriving `returns-it`. **Classifier-2 set unchanged at `{env_get}`** — measured, and for the
reason D16 established, arrived at without a widening because these fields were born wide. **Nothing
routed**; zero call sites on either surface, reported rather than presented as coverage.

**THE RECORDING DECISION, AND IT REPLACED D3'S REASON RATHER THAN INHERITING IT.** Writes recorded,
reads not — D16's choice — but D3's stated reason (*"until a fixture seeds `WorldState.files`, a
replay cannot lose what no run put there"*) **named its own expiry condition, and this item is what
creates it.** The replacement is a measurement I verified: **`InitialWorld` carries
`synthetic_environment` and has NO `files` counterpart** (`dst_program.ail:76-80`), and
`world_state_of` builds from `empty_world_state()` setting script/clock/approvals/**env**/tools —
**`files` is never reconstituted** (`dst_replay.ail:745-754`). So an env read reads a value **the
program supplies** and a file read reads one **it does not**. **Recording both — the obvious way to
"close D3's asymmetry" — does not close it**: it produces a log describing observations whose source
the artifact cannot rebuild, the two-homes shape one level up, in the instrument. **The write is
recorded for GRADING, not reconstitution** — a difference in kind from the other four recorded classes,
and stated at `recording_ports`.

**`removeFile` BUILT, `mkdirAll` DEFERRED, on two different grounds rather than one budget line.**
Remove because *D16's argument for the write is remove's argument verbatim* — it changes what
`fileExists` returns and compose branches on exactly that — so deferring it would be adopting an
argument and refusing its conclusion. `mkdirAll` because directory existence is observed only through
`isDir`/`listDir`, which have no core seam, so a mediated `mkdirAll` would mutate a table nothing can
read. **6 of compose's 18 write-side sites stay unroutable until the directory seam exists.**

**THE VALIDATOR RULE WAS WIDENED, AND THE NEGATIVE CONTROL SAYS HOW FAR.** `OutcomeMissing` is now
admitted for `file_remove` **and nothing else** — verified in `dst_program.ail:341-399` — on WI-A13's
reading B, with `OutcomeOk` rejected as indistinguishable from a real delete and `OutcomeFault`
rejected because A7's catalogue declares no filesystem class. **`file_write` stays refused, asserted by
mutant 12d rather than described.**

**TWO-TIER COMPATIBILITY, THE FIRST IN THIS PROJECT AND IT WILL RECUR.** Adding a constructor made
`program_persistence`'s two rows mutually unsatisfiable — the specimen must carry every class, and the
frozen v1 bytes must not be regenerated (*"it destroys the evidence"*). Resolved structurally: **a
class added after the freeze cannot be in the frozen bytes by construction**, so
`frozen_v1_interactions()` is pinned forever and `specimen_interactions()` = frozen ++ post-v1. **The
cost is stated rather than buried: the two new classes' codec paths are ROUND-TRIPPED, NOT FROZEN**,
and nothing in the tree can freeze them. I confirmed `scripts/dst/fixtures/` is untouched.

**The census fail-open my handoff named is CLOSED and made a tripwire**: both classes pinned at zero in
`dst_discovery.absent_classes`, so **the moment part 2 routes a write, `check_discovery` goes red** and
the routing item must give the class a witness or move it out, having said which.

**Three guards fired that this item never touched** — `invariants`, `program_persistence` and D16's own
reachability assertion — each because it derives its subject list from `all_interaction_kinds()`.
**D16's assertion earned itself on the first addition after it landed:** two named failures where the
pre-D16 suite would have printed five green rows and said nothing.

**Counter at 72; both instances are on this class's own subject matter.** Site 1 is
`scripted_file_write` returning `next_state: state` — what five of the six other deterministic adapters
legitimately do and what `ambient_file_write` legitimately does one screen away. Site 2 earned **S26**.
Verified green at review: `invariants`, `program_persistence`, `discovery`, `execution_program` all
pass, exit 0; classifier-2 selftest 0 failures, 7 fields derived and 7 pinned.

**ABI rows now TWELVE** (9 changed + 3 added), plus three added types. Still not cut; `ailang.toml`
unchanged at 5.0, verified.

**WI-D16, 2026-08-07 (~1h39m; the ~1h25m first recorded here read a D15 leftover commit as D16's start) — ROUTE B PART 1. `ExtPorts` 4 fields → 5, classifier-2 members 2 → 1.**
Verified at review: `proc_exec` now `(ExtWorld, string, string) -> ExtProcOutcome`, a new
`file_read: (ExtWorld, string) -> ExtFileRead`, and **`CLASSIFIER-2 SET (1): env_get`**. The pin went
red on the widening and was moved deliberately, read as *membership* rather than as an exit code —
`returns-it`, not `derive.py`'s fail-open `unrouted`. **Nothing was routed**; both new seams have zero
callers, which is D3's "first exercise of a seam with no callers" state, reported rather than presented
as coverage.

**THE WRITE/PRINT DECISION, AND THIS HANDOFF'S FRAMING LED TO THE WRONG ANSWER.** I framed it as *"a
file write is not an observation and neither is `println`"* — true, and **the wrong question.** The
decision is **writes IN the world (option 2), `println` OUT (option 3)**, and what splits them is
whether the session ever observes the result.

**Measured in compose rather than argued from D1's sentence, and verified at review**
(`compose.ail:502-521`): `writeFile(snippet_path, …)` → `check_snippet(snippet_path)`, which **shells
out to that path** → `if not checked.ok` → `fileExists`/`removeFile` → `run_snippet` reads it again.
**The write is never observed by a `readFile`; it is observed by a `proc_exec` and a `fileExists`, and
session control flow branches on the result twice.** So if `proc_exec` and `file_read` are mediated and
`writeFile` is not, a deterministic run mutates the real filesystem, then asks the world what that path
contains, and gets an answer the disk contradicts — **two homes for one fact, which is `ADR:340-341`'s
"exactly one home, visibly threaded" and F6's shape exactly.** `println` has no second reader, so the
argument does not carry: nothing in a session can observe stdout.

**Half the decision is OWED and named as its own item: `Ports` has no `file_write` core class.** A
`ExtPorts.file_write` fronting nothing would derive `unrouted` — a field that looks like mediation and
is reported as a bypass — so **the core class must exist before the extension seam can front it**, and
that is WI-D3's shape, which was a whole item for the READ half alone.

**Two findings for the next item, both measured:** eight fixtures carry the stale
`["ai_step", "env_get", "proc_exec"]` set at `abi_version "4.0"` — **stale since B2b and C5, four items
passed over them, and nothing guards them** (confirmed at review: exactly 8 files). And **part 2 is
blocked on more than it looks**: routing compose needs the write class **and** a directory seam
(`Ports` has none, and compose calls `listDir`/`isDir` at three sites) **and** door 3's producer.

**ABI rows now TEN**, plus two added types. Still not cut; a lockstep re-release is a release act.

**WI-D15, 2026-08-07 (~45 min) — CRITERION 2 QUANTIFIES OVER HOOKS. The closure was never the
scope.** The reading rests on two sentences already in the ADR: D5 says *"every hook reachable within
that profile"*, and Amendment A's property 2 **opens by agreeing and derives the unit from it** —
*"criterion 2 quantifies over every hook … **so** the unit is the extension's transitive module
closure."* **The `so` is the whole argument**, and the amendment already calls its own unit a
*coarsening* that *"caps the instrument's reach at four extensions."* **A coarsening is not a
definition.** So the tree never held a contradiction between classifier 3's verdict and
`driver_only.ail:597` — it held a conservative instrument and a sharper claim, and nothing compared
them.

**`driver_only.ail:597` was scoped correctly in KIND and wrongly in EXTENT** — one file is too narrow
(the hook is bound in `register.ail`), the closure is too wide, and the right unit is neither.

**The obvious sharpening is FAIL-OPEN, and the repository refutes it rather than an argument.**
Dropping `register.ail` from the closure clears `microrag` of two ambient sources a hook really
reaches — verified at review: `microrag_tool_handle` is a **named top-level hook function defined in
`register.ail:160`**, and that file imports `std/process (exec)`. **9 of 15 extensions hold the
`ExtensionHooks` record in `register.ail`; 6 declare named hook functions there.** The split is
reachability-granular instead.

**Yield 4 of 15 → 5 of 15, and the sets are NOT nested**: `mcp` and `test_dummy` added — both the D6
confound exactly, registration reads `Env`/`FS` and the hooks close over the data — and
**`compaction_structural` DROPPED**, on **door 3**, not on behaviour. See S16's extension.

**The verdict is REPORTED, not promoted, and that is deliberate**: `ext_hook_scope` is a reporting
target, the barrier derivation still reads `ext_ambient_inventory`'s closure verdict, and the selftest
asserts the shipped verdict has **not** moved so a future edit cannot promote it quietly.

**Route B's cost, re-derived: cheaper to SCOPE, not much cheaper to DO.** For `compose` the surface
falls from **17 modules to 6** while the source count barely moves (**28 → 23**); `context_mode`
roughly halves on both. **And a prerequisite appears that D9 did not price:** `compose` and
`context_mode` are HOOK-UNRESOLVED on door 3 **regardless of Route B**.

**WI-D14, 2026-08-07 (~50 min) — THE SECOND PROFILE EXISTS, AND ALL FOUR OF ROW 3'S
INSTALLED-EXTENSION CLAUSES BOUND AND HELD.** `driver_plus_no_ops/1`: four extensions installed, **32
hooks covered, zero of them mediating the world**. Verified at review — each of the four extensions
reports *"8 hook(s) covered — floor satisfied, non-vacuously"*. Those clauses had quantified over the
empty set for the entire project. **Clause 3 is half-bound and says so**: the AILANG rule still
quantifies over an empty derived call list, and what discharges it substantively is classifier 3
reporting **0 `ExtPorts` field calls** per installed closure — a measurement on the other side, named
as such rather than claimed as a green line.

**Row 3's fifth clause — "visible as such" — needed a FIELD, not the ids.** A no-op hook and a
mediating one disclose the same eight names, so `HookClassificationEntry` gained
`clauses: Criterion2Clauses`, one status per criterion-2 clause. **Before it, "this hook mediates the
world" and "this hook performs nothing, so there is nothing to mediate" wrote the same string into the
same record** — `basis`'s defect one level down.

**The coverage statement is COMPUTED, and the D5 caveat survives rather than being deleted:**
*"NON-ZERO and ENTIRELY OF NO-OPS: 32 hook(s) … 16 satisfy criterion 2's port and origin-tag clauses
VACUOUSLY … a weaker claim than the number implies and a stronger one than zero."* `coverage_statement`
still returns the ZERO sentence for an empty install list, and the guard **fails** a profile that
reports non-zero coverage without saying none of it mediates. **The fifth vacuity was made into a
rejection rather than a resolution.**

**The four changed rows were re-earned on grounds that are NOT emptiness** — row 4's waiver by
measurement (0 `ExtPorts` calls, so no installed hook can issue the class's delivery request), row 5's
transfer by measurement (0 ambient sources, so installing four added no reachable core site), row 7 by
two independent facts either of which suffices. **The other seven are explicitly NOT claimed**, in the
script's own output.

**And it produced the first LIVE instance of this project's counted failure mode in thirty-eight
runs — see S23.** The counter moves **69 → 70**, and determinism did not catch this one either.

**One correction applied at review: the stdlib-adjacent cache's producer is STILL UNIDENTIFIED.**
WI-D14 reports it as *"IDENTIFIED, and it is `make sync_packages`"*, but its evidence is
`find ~/.ailang` — **a different directory**. Measured: `~/.ailang` holds **4 files** (a registry copy
of `sunholo/logging@0.4.0` plus `state/collaboration.db`, exactly what D14 lists), while
`~/.local/share/ailang/std/.ailang` holds **52** — the stdlib compile cache whose warmth moves
`effect_inventory_selftest` between `agree=1` and `agree=45`, and the one D11, D12 and D13 were
chasing. D14's own scope note concedes it does not account for the 52. **What it identified is real
and is not the open question.**

**WI-D13, 2026-08-07 — `basis` LANDED, THE BARRIER DERIVATION RE-SHAPED, AND FOUR EXTENSIONS CLEAR
— NOT ONE.** Verified at review: `basis` rejects three ways by name with a loading control, the
producer catalogue re-derives **3 measured (each with a Makefile target) and 2 assumed (deliberately
without one)**, the SLOT-level count is still **3**, and the per-`(extension, slot)` derivation reports
**33 of 45 pairs stand** with `compaction_structural`, `decision_framework`, `empty_stop_guard` and
`progress_contract_guard` at **zero barriers**. `driver_only` **v12 → v13**, installing nothing.

**The criterion decision, which is the item's durable output: CRITERION 2, with two of its three
clauses VACUOUS.** Criterion 1 is **unavailable rather than unearned** — all twelve barrier-slot
bodies of the four extensions accept a rowless declaration with a `println` control rejecting each, so
it is true in substance, but criterion 1's basis is the declared row and the ABI's closed rows forbid
narrowing. **So the handoff's criterion-1 stop rule did not fire, and the reason is that criterion 1
has no route rather than that the answer is criterion 1.**

**Clause 2 fails closed and says so.** No producer exists for *"is this port call origin-tagged"*, so
the derivation clears a barrier only when classifier 3 reports **zero** `ExtPorts` field calls — i.e.
only when there is nothing to tag — and refuses with `clause 2 UNDISCHARGED` otherwise.

**The trigger fired and was discharged by NAMING rather than by red.** An extension at zero barriers
must appear in `installed_packages` or `omitted_extensions`; naming is not a coverage claim, installing
is. Two-sided: removing one entry after the other four landed reddens **per extension, by name**.
**The four are OMITTED** — see S21's extension for the reasoning, which is about evidence rather than
correctness.

**The profile now states the thing D6 got wrong, correctly scoped:** *"the empty install list is a
CHOICE rather than a consequence for them, and a consequence still for the rest."*

**And the handoff anticipated one extension where four clear.** `compaction_structural`'s
distinguishing property — the one binding of fifteen that uses a named top-level function, making its
declared row *operative* where the other fourteen's is inert — is **orthogonal to the clearance**,
because classifier 3 does not read declarations at all. The other three were already in classifier 3's
`4 of 15` and nothing separated them once the derivation had a per-extension unit.

**WI-D12, 2026-08-07 (~1h02m) — CLASSIFIER 3 IS BUILT, GREEN, AND IN `make dst`.**
`tools/ext_ambient_inventory/derive.py`, fourteen fixtures, two targets **inside the aggregate gate**.
Verified at review: both exit 0, **`RESOLUTION 19/19 std modules (100%)`**, **`PORT-MEDIATED (4 of
15)`** — `compaction_structural`, `decision_framework`, `empty_stop_guard`,
`progress_contract_guard` — **`UNRESOLVED (0)`**, selftest zero failures. **Third independent
derivation of 4 of 15, from a producer neither prior derivation used.** Zero AILANG source files
changed.

**It did not inherit classifier 1's cache defect, and the reason is structural rather than careful:
the tool ESTABLISHES its own precondition**, running `ailang check` over each of the fifteen
registrable extensions before deriving. Measured two-sided — **a cold tree with `--no-provision`
reports 0 clean / 15 unresolved / exit 1**, which is the `agree=0 disagree=0` shape refused in the
denominator, where it can be refused. Resolution is printed as a fraction and anything short of total
is exit 1.

**Its sharpest finding was in neither the handoff nor the amendment — see S16's builtin-door
extension.** An import-only inventory would have cleared `compaction_structural` with an unaudited
`_list_length` call in its closure.

**And it corrected the ADR's own parenthetical — see S22's quantifier extension: the textual route's
yield is 0 of 15, not 1.**

**The barrier count is still THREE and classifier 3 does not move it.** A classifier clearing an
extension does not clear a barrier; a profile installing one does, and nothing is installed.
**What is unblocked: `compaction_structural` is now the tree's first extension for which criterion 2
is established by measurement**, and nothing else stands between it and the first non-zero
extension-model coverage number in this project.

**One instrument observation carried forward and strengthened:** the stdlib-adjacent cache stayed at
**0 files** through the cache-cold sweep, through `make sync_packages` in isolation, and through
`make dst` in full — twice. WI-D11 recorded 52 after that sequence. **What produces that cache remains
unidentified and nothing this repository runs is a candidate**, which removes one more explanation for
classifier 1's owed repair rather than supplying one.

**WI-D11, 2026-08-07 (~21 min) — DOES THE NAME ADOPTION STAND? **YES, QUALIFIED.** Zero files
changed.

**The sentence that appeared to unseat the adoption has a FALSE ANTECEDENT, and it has been false
since 2026-08-03.** `ADR:2038` reads *"**Classifier 2 is not built**, so D5's routing audit as a whole
remains non-citable as name-adoption gate evidence until it is."* **Classifier 2 was built at WI-A4
(`5ad3433`) and passes its published criterion** — verified at review, `make
ext_call_inventory_selftest` exit 0, *"self-test: 0 failure(s)"*, fail-closed on all four
unresolvable forms with a resolving control beside them. **So the routing audit's stated blocker was
discharged three days before D5 adopted the name, and D5's adoption was sound.** D5 did not reason its
way there — it checked D10's two conditions and never mentioned citability, and **neither did this
reviewer's handoff.** It was right without checking.

**D10 states TWO conditions, quoted and joined by "and"**, and `ADR:2463`'s gate-mechanism sentence is
120 lines away in another section, glossed by its own colon as a constraint on **one instrument cited
for one purpose** — corroborated by `ADR:2036-2041` and `PLAN:3201`, both of which make citability a
two-classifier condition on the *audit*, not a five-mechanism condition on the *name*.

**The constraint bites on exactly ONE of the eleven rows.** Row 5 names the routing audit in its own
text and its evidence is that audit's output. **Row 3 names classifier 2 and borrows nothing from it**,
because `driver_only` installs nothing so the quantifier is empty — **the fifth thing the empty install
list buys**, and the reading that could have gone the other way.

**The qualification is classifier 1, and the measurement turned out BOUNDED rather than unbounded** —
the opposite of what this handoff expected. **No repository operation produces the 230-file stdlib
cache**: a 243-file cache-cold sweep leaves it at 0, `make dst` in full leaves it at 52, and the
selftest reads `agree=1` in both. So under **every cache state this repository can establish**,
classifier 1's coverage against the amended criterion is **0/21** and it fails. **Its derived set is
cache-invariant** — 13 effect-bearing / 8 proven-effect-free, byte-identical cold and warm — so what is
missing is the *validation*, not the answers. That is why it qualifies the name rather than unseating
it, and the repair now carries one more requirement: **state a cache precondition, or the repaired
gate measures the cache again.**

**Two findings reported and left, both the acceptance reviewers' or an owner's:** the gate table's
State column (see S15's extension — three of five rows say "Deferred" for built, green mechanisms),
and `head_inventory()` feeding `validate_completeness` its own output (see S16's extension).

**THE AMENDMENT REVIEW, 2026-08-06 — BOTH ACCEPT WITH CONDITIONS. B first, then A, then the table.**
`REVIEW-adr-001-criterion-2-amendment.md`, by a reviewer independent of D6/D7/D8/D9. **Neither is
Revise**, and per the handoff's question the revision is to *neither* A's argument nor its fail-closed
default. **All four re-derivations confirm D9**, and two of them are stronger than D9's own.

**D8's 8/7 was reconstructed arithmetically, which D9 could not do**: 8 sites with `on_pre_step:` and
`func` sharing a line, 6 with the label alone on its line, 1 named — `8 + 6 + 1 = 15`, and `6 + 1 = 7`.
**D8's table was a line-keyed count reported as a binding-form count, and it contradicted the
mechanism D8 stated four paragraphs above it.** Confirmed independently at review.

**Four conditions on A, all additions, and A-4 is the one that changes WI-C5's ordering a third
time.** A-2: the Route B sufficiency clause is wrong in the *permissive* direction — a fail-closed
closure classifier would report `compose` (17 modules) and `context_mode` (7) **dirty** on their std
imports, so "Route B plus classifier 3 buys all three barriers" is false for the two extensions it
names unless Route B also strips every effect-bearing import. A-3: classifier 3's honest yield is
**4 of 15** extensions, not fifteen. **A-4: classifier 3 ALONE, with zero Route B work, would clear
all three barriers for `compaction_structural`** — verified at review: its three barrier-slot bodies
are measurably effect-free, its closure imports only effect-free stdlib, and it is the **one**
extension binding `on_pre_step` as a named function. **That is the tree's first installable extension
and the cheapest path to a non-zero coverage number, and the draft never names it.**

**The architecture test clears classifier 3, and the handoff's D5-level escalation does NOT fire.**
Its absence degrades to exactly HEAD, which is the ground both acceptance reviewers used for the other
three. And the escalation is refused on a measurement: a measurably-effect-free hook is blocked by the
**ABI record's closed row** — a named binding cannot declare narrower than its slot — not by the
classifier layer. **So the extension model is uncovered, not uncoverable by construction**, and the
route that needs no classifier is an ABI change already sitting inside the deferred major.

**A cannot license a `WorldMediated` classification at HEAD** — verified four ways — **but the
prohibition is unenforced prose.** `classification_agrees` validates a `WorldMediated` entry against
the excluded-id list and nothing else; **what actually keeps it unreachable is the barrier count.**
True before the amendment and not worsened by it.

**Applying it is three edits with three different owners**, and only the third needs the acceptance
reviewers: the table gains a **fourth** deferred mechanism where `ADR:20-22` and `:2113` both say
three. **Condition A-1 blocks that edit specifically** — see S13's extension; classifier 1's row must
not keep reading "Built and independently verified" in the pass that adds a row beneath it.

**WI-D9, 2026-08-06 (~39 min) — CRITERION 2 ADMITS EVIDENCE. NOTHING CAN PRODUCE IT. COUNT STILL
THREE.** The answer splits, and which half fails is the item's value.

**Half 1, the reading — YES, and the ADR concedes it.** Criterion 2 (`ADR:1290-1291`) names no
declared row; the declared-row rule is a separate sentence at `ADR:1392` beginning **"Per-hook
classification reads *declared* effect rows IN THE INTERIM"** — a convention with a stated expiry.
Eleven items were right to use it; none tested whether it is what refuses `on_pre_step`. It is.

**Half 2, the evidence — NO, and it is a CATEGORY ERROR rather than a gap.** The successor detector
the ADR defers reconciles **labels**; criterion 2 is a claim about the **call path**. Measured
two-sided against the shipped ABI: a fully port-mediated body and a fully ambient body, at the
**identical declared row**, get the **identical verdict** — with a control (each arm one effect short)
rejected, proving the checker is running and label-sensitive. **The effect checker is blind to
provenance by construction, and no reconciliation of label sets at any precision produces the sentence
criterion 2 needs.**

**So the declared-row rule is RETAINED as the fail-closed default**, two amendments are **drafted not
applied** (D5 is Accepted), and a narrower "named bindings plus ambient-free closure" amendment was
**refused on fail-closure** — mutation-measured: one `getEnvOr` added inside `compaction_ai`'s
`on_pre_step` lambda leaves `ailang check`, `make profile_definition` and `make declared_vs_performed`
**all green and byte-identical**.

**THE ORDERING IS THE MOST USEFUL OUTPUT: Route B alone clears ZERO barriers; Route B plus a new
CLASSIFIER 3 clears all three.** `check_fixtures.py:226-230` states the category error in the gate
itself — *"an effect label is never a port"* — so criterion 2 is unsatisfiable by construction for any
non-empty row whatever the behaviour underneath. Classifier 3 is a **provenance** instrument
(positive port-call inventory + per-extension ambient-source enumeration at symbol granularity), it is
**not** blocked by the record-field limitation, and it is **ordered before Route B**.

**And it corrected two things this reviewer carried.** The binding-form split is **14 inline / 1
named**, not D8's 8/7 — re-derived here with S22's falsifier and **independently confirmed at review**:
only `compaction_structural` binds `on_pre_step: pre_step`; the other fourteen bind inline, six of them
with the label alone on its line, which is what a line-keyed classifier miscounts. **So D6's, D7's and
D8's recorded enforcement prize is real at ONE binding of fifteen, not seven.**

**WI-D8, 2026-08-06 (~80 min) — `ExtPorts.ai_step` MEASURED FOR THE FIRST TIME. OVER-DECLARED BY
SEVEN. THE BARRIER STILL STANDS AND THE COUNT IS STILL THREE.**
D7's `on_pre_step` conclusion rested on the clause *"whose own port row is exactly those ten"*, taken
as given. **It was never measured.** The port's entire effect demand comes from `session.ext_ai_step`,
whose whole body is one call to `Ports.model_step` — `! {AI, IO, Trace}` since WI-A1 — and the effect
checker names it from the body: `Effect checking failed for function 'ext_ai_step' … Missing effects:
AI, IO, Trace`. **The other seven — `Process`, `FS`, `Env`, `Net`, `SharedMem`, `Clock`, `Stream` —
are effects `model_step` cannot produce.** Both rows narrowed to `! {AI, IO, Trace}`; the chain
fixpoint was re-derived one function at a time; 14 of 15 bindings still accept the empty row and
`compaction_ai` still refuses, now at three effects rather than ten.

**THE DECISION, taken against D5 criterion 2 read directly rather than inferred from the narrowing:
`on_pre_step` REMAINS A BARRIER and D7's vocabulary conclusion SURVIVES.** At ten effects the row was
positive evidence *against* mediation; at three it **stops contradicting** the claim without
**starting to support** it, because `! {AI, IO, Trace}` is equally consistent with an ambient
provider call. `make profile_definition` derived `3` on its own and no artifact had to be told.

**AND THE ITEM'S LARGEST FINDING WAS NOT IN ITS MISSION: AILANG DOES NOT EFFECT-CHECK A LAMBDA'S
DECLARED ROW IN RECORD-FIELD POSITION — WHICH IS HOW EVERY HOOK IN THIS TREE IS BOUND.** Measured
across four positions (top-level, `let`, argument, record-field): only record-field is unchecked. An
empty row on a lambda is separately not a claim at all — it reads as *unannotated, infer*. **So the
prize D6 and D7 both banked — "a binding that starts reading `Env` now fails to build" — is true for
the 7 of 15 `on_pre_step` bindings written as top-level functions and false for the 8 written
inline.** The effect is not lost, it MOVES: it propagates to the enclosing `register_with_config`,
whose row is checked — and `Env` is admitted by **all fourteen** registration rows that exist. **The
enforcement lives one level up from where three items have recorded it.** Both limitations are now
gate rows that go **red when FIXED**.

**WI-D7, 2026-08-06 (~45 min) — THE OTHER THREE MEASURED. NONE FELL. THE COUNT IS STILL THREE.**
Route A is **refused for all three slots**, each by exactly **one binding of fifteen**, and the
compiler names the refuser every time: `on_pre_step` by `compaction_ai`, `on_response_intercept` by
`compose`, `on_solver_candidate` by **`context_mode`**, whose `finalize_with_index` spawns a `node`
bridge fire-and-forget on the default path — verified at review at `context_mode.ail:185`. **My
handoff predicted Route A for that slot and "genuinely open" for `on_pre_step`; it was right once of
three.**

**Two rows narrowed anyway and neither removes a barrier** — `on_response_intercept` to
`! {IO, Process, FS, Clock}`, `on_solver_candidate` to `! {Process}` — because a non-empty row fails
criterion 1 at four effects exactly as at nine. **What the narrowings buy is the compiler**: a binding
that starts reading `Env` now fails to build where at nine effects it compiled silently.

**`on_pre_step`'s barrier is the ROW'S VOCABULARY, and that is the item's sharpest result.** Its one
performing binding reaches all ten effects through a **single call to `ctx.ports.ai_step`** — a D1
world-mediated port — and returns `next_state`. **Criterion 2's substance is already satisfied.** What
refuses it is that criterion 2 is evaluated against the *declared* row, and **a declared row has no
vocabulary for saying an effect arrives through a world-mediated port.** No narrowing reaches that; it
needs a port-surface change or a criterion that can read mediation. B4 argued this, and it is now
measured.

**The runtime capability trap reaches ZERO of fifteen on these slots** — not a reduced fraction, zero,
because the effects at stake are the ones `register_with_config` itself performs. **So the compiler is
not the third producer here, it is the only one**, and the gate says so rather than implying a witness
it does not have. That is D6's fraction rule returning the answer it was written to make visible.

**The barrier count is now a DERIVED, CHECKED ARTIFACT** that goes red at zero. Verified at review:
`make profile_definition` prints `3 barrier(s) stand, so NO extension is installable in a conformant
profile`. **This is D5's planning defect 4 discharged for the claim that most needed it.**

*(One correction to D7's own corrections list: it states that D5's and D6's plan entries are still
owed. Both exist — written at review — and this entry makes three.)*

### WI-D7 — the three remaining barriers, measured. **NONE OF THEM FELL. THE COUNT IS STILL THREE.**

**Executed 2026-08-06.** Method: each slot's row narrowed to nothing tree-wide, then all 71 files of
the fifteen packages derived from `registry_generated.ail` re-checked. That makes the **effect
checker** the producer, which is total over inputs where the capability trap is a witness over one
path — and here it is the **only** producer, because the per-process capability confound D6
documented blocks the runtime arm for every one of these subjects.

**Fourteen of fifteen bindings accept the empty row in every slot. Each slot is refused by exactly
ONE, and the compiler names it:**

| Slot | Refused by | Effects, per the compiler | Row after D7 |
|---|---|---|---|
| `on_pre_step` | `compaction_ai` | all ten, via `ExtPorts.ai_step` | **unchanged** — ten |
| `on_response_intercept` | `compose` (inline path) | `Clock, FS, IO, Process` | **narrowed** 9 → 4 |
| `on_solver_candidate` | `context_mode` | `Process` | **narrowed** 9 → 1 |

Each confirmed a second time from the **body** rather than the annotation, by narrowing the refusing
helper's own row: `Effect checking failed for function 'fresh_compaction'`, `'on_response_intercept'`,
`'finalize_with_index'`.

**THE PLAN'S OWN CLAUSE ABOVE WAS WRONG, AND THIS IS THE CORRECTION.** The D6 correction paragraph
says the other two slots "declare nine effects while returning constants". **`on_solver_candidate`
does not.** `context_mode.finalize_with_index` spawns a `node` bridge fire-and-forget to index the
final output — a real subprocess, on the default path. Twelve of the fifteen bindings *are*
constants, which is how both the handoff and this plan came to say all of them were. **S22 again, and
this time it bit a barrier count rather than a subject count.**

**NEITHER NARROWING REMOVES A BARRIER.** A non-empty row fails D5 criterion 1 at four effects exactly
as at nine, and none of `Process`, `FS`, `IO`, `Clock` is a world-mediated port, so criterion 2 fails
too. What the narrowings buy is the **compiler**: a binding that starts reading `Env` in either slot
now fails to build. **Three barriers stand and no extension is installable** — and that count is now
**derived on every run** by `make profile_definition` from the ABI rows and the dispatch table, and
goes **red if it reaches zero**, because that is WI-C5's trigger rather than an ABI edit's side
effect.

**THE SHARPEST FINDING IS `on_pre_step`, AND IT IS A SHAPE FINDING RATHER THAN A MEASUREMENT.**
`compaction_ai` reaches all ten effects through a single call to `ExtPorts.ai_step` — which **is** a
D1 world-mediated port, returning `AiStepOutcome.next_state`, which `compact_with_ai` returns rather
than `ctx.world`. **Criterion 2's substance is already satisfied by the only binding that performs
anything.** What refuses the slot is that criterion 2 is evaluated against the *declared row*, and a
declared row has no vocabulary for saying an effect arrives through a world-mediated port. **The
barrier there is the row's vocabulary — not the behaviour, and not the row's width.** No amount of
narrowing reaches it; it needs either a port-surface change or a criterion that can read mediation.

**`driver_only` v11 → v12**, and it is a claim change with no anchor moved: v11's header said the
empty install list had become CHOSEN. **It is still FORCED.** The file had disagreed with itself for
one item — its `omitted_extensions` reason said the three barriers stood while its header said the
emptiness was a choice, both written by D6 on the same day, and nothing went red because no artifact
computed the count. **That is now the checked artifact.**

**WI-C5. The second profile: `compose`-bearing.** Depends on **B2, A5, A10 and A12** — B2 for the
coverage widening, A5 because its routed-set claim is a routing-completeness claim gated on the
attribution table, A10 for the profile machinery it instantiates, A12 for the world clock its
extension reads route *into*. An earlier revision named only B2; milestone order does not supply
the rest, because B interleaves with A and C5 carries no all-of-A guard the way C4 does. The
dependency on B2 is not just the clock: `compose` puts real behaviour in an
unconditionally-dispatched nine-effect hook
(`on_response_intercept`, bound at `compose.ail:840`, body at `:761-790`), which under the
declared-row rule cannot be covered and — being unconditionally dispatched — cannot be excluded
either, so `compose` is un-installable in a conformant profile until B2's world-token/coverage
widening lands. (Its `on_tool_handle` is the one *gated* hook and could be excluded; that does not
rescue the install.) The work:
route the eight `motoko-ext-compose` clock reads through `ExtPorts.clock_now` (first exercise of a
seam with zero call sites today — budget for it not surviving contact unchanged), make the
effectful hooks world-mediated, **land `routing_violation_at`'s call site** — reassigned here from
A13 by cluster 9, because the check discriminates on a hook id that no interaction carries, its real
consumer is the production hook dispatch site (`ext/runtime.ail:279`), and C5 is the first profile
that can legitimately exclude a hook and so the first where it is non-vacuous — and claim the routed
set — **12 sites post-table; 13 is the
fail-closed figure if the attribution table is absent or invalid** (D4's 4/12/13 versus 5/13/13
split).

**CORRECTED AT WI-C5: THE 12/13 PAIR IS STALE AND NO NUMBER SHOULD BE TRANSCRIBED HERE AT ALL.**
D4's 4/12/13 and 5/13/13 predate WI-A5's measurement of the actual inventory, which found **seven**
unconditional-core clock sites rather than thirteen. `dst_attribution_table` has carried the
correction for the routed half since A5 — *"D4's table says four and predates it"* — and it was never
propagated to the totals, so the C5 handoff inherited a stale pair from the ADR. **The claim is
COMPUTED by `dst_profile.routed_set_claim` from the table at the revision the profile binds**, and
`driver_only`'s acceptance prints the computed answer against this prose rather than asserting either
number. Read the claim, do not transcribe it. The dispatch-time exclusion check A10 installs becomes binding here, and its in-runner
probe — reaching an excluded hook returns a typed `HarnessFailure` with partial evidence — is part
of this item's acceptance rather than assumed from load-time validation.

## Deferred artifacts: build step and acceptance evidence

The four artifacts the handoff requires scheduled, none of which blocks the ADR and all of which
block the name:

| Artifact | Built in | Acceptance evidence |
|---|---|---|
| Classifier 2 | WI-A4 | Gate-table criterion: fails closed on unresolved occurrences; two known call sites at HEAD; repin re-derivation wired in (WI-B4) |
| Site-to-hook attribution table | WI-A5 | Gate-table + D4 clause 3: schema/staleness/referential validation fail closed; **plus producer-side completeness — a classifier-discovered site in neither the rows nor the unconditional-core set is rejected at load**; named reviewer per row as the stated exception; empty-intersection semantics tested |
| Coverage-floor validation | WI-A6 | Gate-table (simplified): unconditional floor + disclosure, both enforced at load; fixture rejections demonstrated |
| D3 fault catalogue / D6 event vocabulary | WI-A7 / WI-A8 | Their own decisions' fail-closed contracts, **including set completeness** — A7 rejects a catalogue missing a required class, A8 round-trips all 34 variants and both `StreamDelta` branches; D6's scheduling prohibition honoured by A14's split dependency, D4's by A12's and C5's claim clauses |

## Milestone boundaries, and what each unblocks

- **Milestone A** ends with: F6 fixed and regression-locked; the routing audit citable (both
  classifiers built and verified); `driver_only` defined, loading, and truthfully claiming a
  4-site routed clock set; discovery/replay running against the real driver; the D7 invariants and
  the D4 latency pair; both D11 corpora and their CI jobs. **Everything the name gate needs except
  streaming parity and extension-model coverage** — and that claim is now true, where an earlier
  revision's was not: it left the latency pair in C4 and the corpora unbuilt while claiming the
  same boundary.
- **Milestone B** (external trigger) unblocks: recorded-stream adoption, the extension model path
  (world-token ABI), and coverage growth beyond the three rowless slots. It is the only milestone
  with third-party latency, and per upstream's own advice the project does not idle against it.
- **Milestone C** unblocks the name. Its gate is the ADR's acceptance-test table, nothing less —
  and C4 only *runs* that table, since every row's evidence is produced in A or B.
  **C1 + C2 landed 2026-08-05** (`c0fbf10`, `12577c2`; ~57 min): `live_ports` adopts
  `stepWithStreamRecorded`, and `make recorded_stream` answers **D1's five clauses in 23 rows across
  two subjects and two outcomes** — the first time they have been answered against a *pinned release*
  rather than a local prototype, which is exactly what D1 asks for. The rejected delayed-projection
  fallback is a **permanent negative control** that the runner asserts must fail, so clause 1 enforces
  the rejection instead of merely agreeing with it. `driver_only` re-issued **v4 → v5** with coverage
  unmoved.
  **What C2's green does NOT mean, stated because it is the available misreading:** D1's substrate
  gate is answered; **D6.4's parity obligation is not discharged.** `live_ports` now *produces* a real
  ordered emission log and **nothing reads it** — `session.ail`'s `exchange.emissions` still goes
  nowhere, `stream_parity_findings` is still exercised only by constructed executions, and the two
  scripted `play_chunks` sites still report `emissions: []` while playing chunks. The gap moved from
  producer to consumer. **WI-C3 is what changes that sentence**, and it is now unblocked in a way it
  has never been: the thing it consumes exists.
  **C3 landed 2026-08-05** (`b145eef`; ~72 min) and **took the BRIDGE option**:
  `dst_execution.execution_of` builds an `ExecutionUnderTest` from a real run, and
  `make stream_parity` evaluates **all sixteen D7 families over an execution a run produced** — the
  first time in this project that any family has been checked against anything but a constructed
  fixture. **D6.4's named stream exception is discharged**; `StreamDelta` left `d64_gap_register` by
  being **appended**, not reclassified, and the register went 14 → 13. **D6.4's general obligation is
  NOT discharged** — twelve of the remaining thirteen are the tool-dispatch fold and the terminal
  paths.
  **The finding that resized the item, and it falsifies what the handoff told C3 to expect:**
  `ledger_emit` writes the wire and calls `emit_trace_event`; it never calls `ledger_append`, which is
  the only thing that puts a record in the returned `LedgerTrace`. **So the returned trace held ZERO
  `StreamDelta` records on every path in the driver's history** — the register said so at the site the
  whole time. It was never "the log has no reader": **both sides were empty, and a parity check over
  two empty lists is green.** The trace append was therefore a precondition C3 discovered, not a bonus
  it picked up — and it was *unwritable* before C1, because there was nothing to append from.
  **The remaining honest gap:** fifteen families run on a real run because they ride along with parity
  in one script, on one profile, with two adapters — not because anything wires them deliberately.
  **C5 landed 2026-08-05** (**~95 min**, `10:39Z → 12:14Z`; the plan first recorded ~55, which
  contradicts the report's own timestamps and is corrected here because these windows are the
  project's sizing evidence) and its durable output is **D5's declared-versus-performed
  detector**, which D5 names and records as unavailable. `make declared_vs_performed` compares two
  genuinely independent producers — the ABI's static effect row, grepped from source, against the
  AILANG interpreter's capability trap observed OUT OF PROCESS as an exit status — and measures that
  **compose's `on_budget_plan` declares `! {Env, FS}` and performs NEITHER.**
  **THE INSTALL ANSWER IS NO, AND C4 SHOULD READ IT AS NO.** `on_budget_plan`
  (`packages/motoko-ext-abi/types.ail:298`) is coverable under neither D5 criterion — criterion 1
  fails on the closed declared row, and criterion 2 fails because `BudgetPatch` **has no `next_state`
  field at all**, so there is nowhere to return world state even if `Env`/`FS` were mediated — and it
  is unconditionally dispatched, so it cannot be excluded either. Changing it is a second ABI major
  and was reported rather than taken. **So `driver_only` still covers nothing provably, and C5 did not
  change that sentence.** What C5 did change: the barrier is now known to be the RULE rather than the
  BEHAVIOUR, which is the input a decision to move that row did not previously have.
  **`ExtPorts.clock_now` was widened** to `(ExtWorld) -> ExtClockReading` and routed through
  `Ports.clock_now` in `ext_ports_of`; `ext_unrouted_clock` is DELETED, `session.ail:878` has left the
  declared-unrouted set, and **plan rule S2's only live exception is retired** (its pin measurement is
  kept in the past tense per S15). The routed set went **5 of 7 to 6 of 7**, computed.
  **`routing_violation_at` has a production call site** in `src/core/dst_hook_guard`, scoped to the
  one GATED slot and driven through the guarded dispatch by `make hook_guard` — **and it is vacuous
  today for the same reason the install is refused**, which the script prints on every run.
  **NOT delivered, and named rather than softened: compose's eight clock reads are still unrouted.**
  Partial threading was rejected as worse than none (a half-threaded world is F6's dropped cursor),
  the full refactor is a 30-parameter recursive function across three files, and the coverage value is
  zero while the package is un-installable.

## Traps carried forward

Verbatim from the handoff, because each has already cost this project time: **PR #103 must not be
merged** (conflicts in six files, reverts `89a1d67`); clear `.ailang` caches before believing type
errors that contradict source; never probe from `/tmp` (`MOD010` auto-relaxes there); the spike
branch is not HEAD state; the `arniwesth/ailang` fork is not the upstream gate — D1 requires a
**release**; the pin is v0.26.0 with a Makefile drift guard.

**Added by execution, each measured:**

- **`--ai-stub` fires the callback exactly TWICE and always returns `Ok`.** Measured at WI-C1:
  `ContentDelta` then `Usage`, returned chunk count 2 — it is a provider without native streaming, per
  `std/ai`'s own contract. **Any gate claiming to exercise chunk ordering, duplication, or provider
  failure through `--ai-stub` is claiming something the substrate cannot deliver**, and partial-stream-
  then-error is unreachable through it entirely. Two chunks and a real stream look identical in the
  output. This is why `make recorded_stream` stands up a real loopback SSE endpoint while every other
  `make dst` target uses the stub.
- **The line-number anchor cascade is NOT half-avoidable**, and `driver_only`'s v3 note claiming it is
  stands refuted at the site. The technique it names — *insert below the anchor, widen import lists in
  place* — covers imports only. WI-C1 moved an anchor with **nothing but a comment** placed above
  `live_ports`, where a reader of `live_ports` will find it, and paid the full re-issue. *Insert below
  the anchor* is not available to a comment whose job is to be read before the thing it describes, and
  avoiding the cascade would mean writing documentation in the wrong place. **Three consecutive items
  have now paid this; the case for a coordinate-independent anchor is no longer speculative.**
  **WI-C3 refutes the rest of the claim and adds the operational rule.** C1 moved an anchor with a
  comment; C3 moved six with a **record field** and an **extracted function**, neither of which has a
  below-the-anchor version — a record's fields have an order, and a converter must be in scope before
  its caller. **Four consecutive items have now paid it, and C3 paid it TWICE in one item**: the second
  payment was caused by three lines of prose added after the first, and was found by `make dst` rather
  than by remembering. **The cascade is not idempotent across an item — finish every source edit,
  including comments, BEFORE running it.** Two consumers exist that no checklist in this project names:
  the `predicate-anchors` script itself, and `attribution_table_dst`'s `omitted_site()` fixture. Both
  were found by a gate rather than by search.
- **A PORT OR RESULT-TYPE WIDENING IS A FIVE-CONSUMER ANCHOR CASCADE, and line-count neutrality is
  unavailable whenever a type gains a field.** WI-D2 moved five anchors adding one field to two
  variants of `ToolDispatchOutcome` and one accumulator to a fold — neither has a below-the-anchor
  form — and paid two source files, four artifact consumers, a profile version bump and a content-hash
  re-record. **D1 avoided the cascade entirely by being line-count-neutral; that route closes the
  moment a type changes shape.** Size a widening as the cascade, not as the edit.
- **A GENERATOR CHANGE IS A FIVE-ARTIFACT CASCADE, and no item that budgets for "add a draw" budgets
  for it.** Measured at WI-D1: editing `choose_provider` re-dated the corpus bank (12 seeds, **not one
  survived**), `seeded_generator`'s S7 fixture *and* its anti-count pair, D8's canary at both versions,
  `run_report`'s declared register, and one mutation row. **Every one went red and named itself**, which
  is the system working — and it still cost about an hour that the item's sizing did not contain. Two
  properties are worth keeping rather than smoothing away: **a mutation row that names a specific
  unreached class self-reports when that class closes** (D1's `required-class-not-covered` mutant named
  `provider_error_retryable`, stopped producing a rejection, and went red saying so — re-pointed rather
  than replaced), and **the two-witnesses rule earns itself exactly here**, since a single-witness bank
  would have lost classes silently when all twelve seeds moved.
- **A tripwire planted for a future item WORKS, and WI-C3 is the first evidence.** WI-A1 spent one line
  asserting `emission_count == 0` in `phase_c2_wiring_scenarios`, with a written prediction of what its
  failure would mean. It fired on the first `make dst` after C3 populated the log — the item it was
  planted for — and was answered by *strengthening* the row rather than relaxing it. **A pin edited to
  match whatever the code now does is not a pin.** This is the cheapest instrument in the project's
  inventory and it should be planted deliberately rather than as a byproduct.

## Out of scope

- Building the interprocedural attribution-necessity validator (D4 names it as its own future
  obligation; the named-reviewer exception stands until then).
- **Shrinking, explicitly deferred past the first name-adoption gate** — recorded here because D8
  permits that deferral only if the project records it. Replay of the unshrunk failing program is
  not optional and is in WI-A13.
- Physical faults, durability contracts, concurrency (D9/Non-goals; the 007-D1.3 tripwire is in
  A7's artifact).
- Any change to the accepted architecture. Corrections to the ADR discovered during execution are
  filed as normal amendments — not review rounds, and not silent reconciliations.
