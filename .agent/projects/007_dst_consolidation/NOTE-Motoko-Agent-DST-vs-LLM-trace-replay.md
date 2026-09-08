Analyse if the Motoko Agent (PR ref: https://github.com/arniwesth/motoko_agent/pull/84) DST system is distinct from just replying LLM traces


Yes — substantively distinct, on four axes. But one of them is currently a claim rather than a fact.

**Where it's genuinely different**

1. **Fakes, not recordings.** Trace replay pins *observed* provider outputs. `stub_step`/`scripted_ports` are pure implementations of the model/clock/approval ports, so scenarios can construct states production never produced — a compaction chain that trips a threshold at step 7, an approval denial mid-tool-pair. The input space is counterfactual, not historical.

2. **The oracle is structural, not equality.** Replay asserts "output matches golden." Your doc explicitly forbids asserting on final prose and instead checks reusable predicates over the typed ledger (`history_valid_transcript`, `validate_compactor_output`, `validate_checkpoint_chain`). That's the difference between a change-detector and a bug-detector — golden diffs go red on every legitimate change, invariants don't.

3. **Nondeterminism is removed, not pinned.** Replay makes *the model* deterministic and leaves clock/env/IO alone. You null out every port and then use caps-as-conformance (`--caps IO` making any raw effect fail at perform time) as a positive proof that the path performed no unmodeled effect. No replay harness can give you that.

4. **Most of the surface isn't about the LLM at all.** L2 tests the TS harness *before AILANG starts* (system-prompt materialization, env/spawn prep). L3 is event parity between two capture paths via `diff -r`. L0 is policy arithmetic with Z3. Roughly 40% of the 54 scenarios sit outside anything a trace could contain.

**Where the distinction is thinner than the framing suggests**

Every scenario is `seed="fixed"`, and seeded generation is deferred. Strictly, that means you have a deterministic *scenario suite*, not simulation testing in the FoundationDB/TigerBeetle sense — no randomized interleaving, no fault injection, no shrinking. The seed field in `Scenario` is currently decoration. So the honest characterization today is: hand-authored fakes driving real transition code, checked by structural invariants. That's strictly stronger than trace replay, but the "simulation" half of the name is aspirational, and coverage is bounded by what you thought to script — exactly the gap randomized exploration exists to close.

Worth noting `deterministic_replay` is one of the four conformance scenarios. Replay is a *property you assert*, one invariant among several — not the testing method. That's the cleanest one-line answer to the question.


Part of the simulator was implemented in  https://github.com/arniwesth/motoko_agent/pull/99


Fetched it. This changes the picture but less than the branch name suggests.

**What actually landed**

One generated family — `compaction.gen.tool_heavy` — plus an RNG canary, at L0 against `compact_for_pre_step`. `dst_gen.ail` is 15 lines (`pick_int`). The rest is the seed loop, `dst_seeded` make target, harness seed-threading, and CI wiring. The L1 families (`phase_c.gen.{split_prefix,seal_boundary,checkpoint_pressure,stage_records}`) are a plan and a handoff in this PR, not code.

**The good parts, specifically**

The RNG canary is the sharpest thing here. Pinning `rand_seed(12345)` → three golden ints means a stdlib PRNG change fails loudly instead of silently invalidating every seed recorded in every past bug report. Most people discover that problem two years late.

The oracle discipline survived contact with generation, which is the usual failure point. Traps 3 and 4 in the handoff — short-content draws *legitimately* produce `PassThrough`, "invariants only, do not tighten" — are the exact instruction that stops a property suite decaying into either flakiness or vacuity. And the one permitted decision assertion is one-sided (`pct < elide_tier_pct() ⇒ not compacted`), matching the one-sidedness the L1 plan mandates for `checkpoint_would_relieve`. Correct property design.

**Where the gap is still open**

1. **This is property-based testing, not simulation.** The seed draws *input parameters* to one call. FoundationDB-style DST randomizes *event orderings and faults* — interleavings, crashes, clock skew. Nothing in #99 generates a schedule. The L1 plan doesn't either: "no scripted model steps, no decision-sequence assertions, do not duplicate phase_c2." So even the planned L1 families are single-step state generation.

2. **It's aimed at the layer that needed it least.** `compact_for_pre_step` is pure. Your own framing says failures cluster at multi-step boundaries — telemetry from step N shaping step N+1. The seeded axis doesn't touch the session driver or the ledger.

3. **Seed alone isn't a sufficient reproduction key.** The canary pins the PRNG, but if someone widens `content_len` to [40, 800], every historical seed maps to a different input and the canary stays green. The trace line prints the params, which mitigates it — but a generator-schema version stamped alongside `family=` would actually close it.

4. **Five fixed seeds in CI is zero marginal coverage.** Default `5 × base-1`, same base every run, means the same five inputs forever — five more fixed scenarios with extra machinery. Boundary-reach was verified at 200 seeds on a scratchpad. The standard fix is a nightly job with a base seed derived from the date, failing seeds promoted into the fixed suite as regressions.

**Revised answer to your original question**

#99 makes the distinction from trace replay stronger — you can't replay a trace you never recorded, and the inputs here were never observed. But it strengthens the *property-testing* claim, not the *simulation* one. The honest name for what's built at HEAD is deterministic scenario + parameter-generated testing.

The move that would earn the "simulation" word: generate a *sequence* of scripted provider steps from a seed — finish reasons, tool-call shapes, telemetry values — drive `session` for N steps, and assert invariants over the whole resulting ledger. `stub_step` already has `Scripted`/`ScriptedStep`, and the ledger already is the trace. That's a small step from what exists and it's the one that would actually hit the boundary bugs.


Now check  https://github.com/arniwesth/motoko_agent/pull/100


PR #100 (`mot-43-l1-seeded-families`) is the implementation of the handoff I flagged as "plan only" in #99. Stack is 84 ← 99 ← 100, all still draft.

**What landed:** a 578-line `scripts/dst/phase_c_seeded_dst.ail` with four families — `seal_boundary`, `checkpoint_pressure`, `split_prefix`, `stage_records` — added as a second `ailang run` line under `dst_seeded`. Two commits, "Reviewed plan" then "Implemented."

**This partly retracts my last critique.** `checkpoint_pressure` drives production transition code: `decide(state, pol)` → `apply_checkpoint` → `decide(applied.state, pol)` again, on a seed-generated state. That's a generated two-step trajectory, not a single pure call. The second `decide` asserting `CallModel` is the interesting one — it's a liveness property (the checkpoint actually relieved pressure and didn't re-fire), and that class of bug is invisible to single-call property testing. So the seeded axis has reached L1 state, which is where it earns its keep.

**The property discipline held.** `checkpoint_pressure` asserts exactly three one-sided things: policy off ⇒ never `TakeCheckpoint`; usage below threshold ⇒ never; and *if* `TakeCheckpoint` *then* the four post-conditions. No converse, respecting the `checkpoint_would_relieve` veto. `state_from_msgs` zeroes all telemetry per trap 2. That's the plan being followed rather than quietly loosened.

**Four concrete findings**

1. **`families=4` is a string literal.** In `run_config`, the PASS line hardcodes the count while the four `run_*_seeds` calls are independent statements. Drop or comment one out and the gate prints `PASS families=4` having run three. That's precisely the anti-silent-drop failure mode the fixed gates' `PASS count=N` oracle exists to prevent, reintroduced. Derive it from the summed family results.

2. **Silent narrowing vs the plan.** `checkpoint_pressure` calls `generated_msgs(1, n_tail, content_len)` — `n_systems` is pinned to 1, and the assertion became `history_len != 2` rather than the plan's `n_systems + 1`. `seal_boundary` draws `n_systems` in [0,2]. So multi-system-prefix histories never reach the checkpoint path. Defensible, but it's an undocumented coverage reduction.

3. **Compaction tiers hardcoded in `policy()`** — 70/85/95 as literals, while `exhaustion_pct()` is properly imported in `seal_boundary`. #99's trap 5 forbade exactly this. It's a config field rather than an oracle so it isn't wrong, but if the defaults move, these four families keep testing the old tiers forever.

4. **The ledger still isn't in the loop.** `apply_checkpoint` is called directly, never through `session`. Your architecture doc names the driver as sole ledger emitter and the ledger as the trace — yet no generated family asserts over a `LedgerTrace`. Every seeded invariant is over `StepState`/history. The layer the framework is *built around* has zero generated coverage.

**Still open from before:** no shrinking (now 4–5 drawn params per family, so counterexamples arrive mid-sized), and CI defaults remain `DST_BASE_SEED=1 DST_SEEDS=5` — 25 generated cases, identical on every run, forever. Five families of machinery producing a fixed input set. Rotating the base seed nightly and promoting failing seeds into the fixed suite is the cheapest thing on this list and probably the highest value.

**Where the naming stands now.** Across #84 → #99 → #100 you've built genuine property-based testing over agent loop state, with a real reproduction contract and honest oracles. "Deterministic simulation" would want generated event *orderings* — a seed producing a sequence of scripted provider steps driven through `session`, invariants checked over the resulting ledger. `stub_step` already has `Scripted`/`ScriptedStep`. That's mot-44, and it's the one that closes finding 4 at the same time.