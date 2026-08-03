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

**WI-A14. Implement the D7 invariant set, the D4 latency pair, and D11 run reporting.** Depends on
A9, A13 (**COMPLETE 2026-08-03 — this item is unblocked**); the parity-classification invariants
additionally depend on A8, **which landed 2026-08-02 — so this dependency is now satisfied and the
prohibition is discharged.**

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
   declared gap and not a solved problem. The provider fault class is *one `ScriptedStep` field away*
   (cluster 10's correction 2, and this item's D4 latency pair is the same field). `ToolCorrelationMismatch`
   and `ToolDeadlineExceeded` are *codec-covered, scenario-unreached*. Three counters, three meanings.
3. **`max_resource_size` is now encoded and round-tripped**, so deleting it is a schema change — which
   is the point of having a schema version. Either give it a resource that can grow or delete it, and
   if deleting, follow D8's migration rule rather than editing the frozen specimen.
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
*Size:* **estimate — 3–5 days.** Basis: eleven D7 invariant families over an existing trace ADT,
plus the latency pair; each invariant is small but the set is wide, and the parity family cannot
start before A8. No measurement covers this; treat the range as coarse.

**WI-A15. Build D11's two corpora and their CI jobs.** Depends on A13 (**COMPLETE 2026-08-03**),
A14. An earlier revision
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
*Size:* **estimate — 2–4 days**, dominated by CI cost measurement rather than code.

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
`src/core/test/` rather than `src/core/`. Also fix or retire `scripts/dst/probe_phase_vocab_sealed.ail`,
which fails at baseline (`IMP010: symbol 'MkHistory' not exported`) and stayed broken precisely
because it is in no target.
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

**WI-B1. Repin the toolchain — preparation-only, not independently green.** Update `ailang.toml`,
`scripts/install-prerequisites.sh:39`, and the Makefile guard together; **clear every
`.ailang/cache` in the tree before believing any diagnostic** (the phantom-type-error trap
reproduced across a version change). The two latent under-declarations (`walk_agents` `FS`,
omnigraph `register_with_config` `Process`) become hard errors and are fixed here.
*Size:* **measured, as one wave with B2/B3 — M2's 381 effect-row edits across 71 files**, almost
all mechanical via the compiler-driven repair loop. M2 is *not* allocated between B1 and B2: three
of its edits are the `motoko-ext-abi/types.ail` row corrections that belong to B2, and the rest are
the mechanical repairs here. Treat the 381 as the wave's total, not B1's.

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

**WI-B4. Re-derive both classifiers on the new pin, and close the repin wave.** Depends on B1, B2,
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
split). The dispatch-time exclusion check A10 installs becomes binding here, and its in-runner
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

## Traps carried forward

Verbatim from the handoff, because each has already cost this project time: **PR #103 must not be
merged** (conflicts in six files, reverts `89a1d67`); clear `.ailang` caches before believing type
errors that contradict source; never probe from `/tmp` (`MOD010` auto-relaxes there); the spike
branch is not HEAD state; the `arniwesth/ailang` fork is not the upstream gate — D1 requires a
**release**; the pin is v0.26.0 with a Makefile drift guard.

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
