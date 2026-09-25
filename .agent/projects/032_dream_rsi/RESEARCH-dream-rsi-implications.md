# RESEARCH: Dream-RSI — "history is already a simulator", read against Motoko's DST and the RSI direction

Date: 2026-09-19
Status: Research note (no decision taken; candidate follow-ons listed in §7)
Grounded at: branch `arniwesth/013-plan003-and-herdr`, HEAD `2062605`
Source:
- T. Zheng, X. Wu, Z. Zhang et al., *Dream-RSI: Recursive Self-Improvement through Evolving
  Worlds*, Google / Google DeepMind / University of Maryland / University of Virginia, 2026.
  Site: dream-rsi.com. Paper: dream-rsi.com/assets/dream-rsi.pdf (36 pp., read in full via text
  extraction). Code: github.com/zhengkid/Dream-RSI — **"being prepared for release" at the time
  of reading**, so every mechanism claim below is sourced from the paper body (§3) and the
  policy-development prompt reproduced in its Appendix B, not from code. Where the paper is
  silent this note says so rather than filling in.
Naming: "DST" below means Motoko's generated axis under a named profile, per
`009/ADR-001` D10. Where a claim depends on a profile it names one; where it does not, it is
about the architecture and holds for `driver_only`, `driver_plus_no_ops` and
`driver_plus_compose` alike.

Relates to:
- `design_docs/planned/m-motoko-dst-recursive-self-improvement.md` (2026-09-12) — the research
  direction this note tests Dream-RSI against. Its three-level table (execution / discovery /
  verification), its "what verified means" triad, and its evolving-verifier rules are the
  yardstick throughout. §3.4, §4.5.
- `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` — D2
  (discovery is seed-driven; replay consumes a resolved program; two replay modes), D3 (faults
  are modeled outcomes), D9 (sequential simulator), D11 (search is a first-class gate; two
  corpora; per-run reporting). §2, §3.2, §4.1.
- `../013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md` — a real session's
  journal becomes an execution program strict-replayed by every candidate, graded by an
  evaluator the candidate does not own. **The closest existing Motoko artifact to Dream-RSI's
  loop, built for a different objective.** §3.1, §4.2.
- `src/core/dst_replay.ail` header — "strict replay compares recorded against actual, and if
  both sides derive from the same defective projection they agree." Dream-RSI's tree recorder
  has the same exposure and no name for it. §3.3.
- `src/core/dst_discovery.ail` (two-sided `class_balance`), `src/core/dst_generator.ail`
  (`check_seed_sensitivity`, content-shaped not count-shaped), `src/core/dst_corpus.ail` (two
  keys; site 22 aliasing) — the anti-vacuity machinery the borrowed ideas would have to satisfy.
  §3.3, §6.
- `papers/motoko-dst-report/DRAFT.md` §6, §8 — the conformance-and-vacuity accounting that
  Dream-RSI's evaluation has no counterpart to. §3.3, §4.4.
- `../030_harness_playbook/RESEARCH-harness-playbook-implications.md` — the note whose shape this
  one follows.

---

## 0. TL;DR

Dream-RSI's thesis in one sentence: a completed discovery run is a tree of attempts with their
realized outcomes, and that tree is an *exact* simulator of the search space that was actually
explored — so alternative exploration policies can be scored against it by reading stored
outcomes, at zero execution cost, and the best-scoring policy is redeployed for the next live
run. "Nothing is predicted: the simulator is exact over the search space that was realized."
The object improved is an exploration controller written as Python code. The coding agent
(Gemini CLI), the evaluator and the scoring function are held fixed.

Read against HEAD `2062605`:

1. **Same trick, different layer.** Both systems refuse to predict: Motoko's D2 replay "never
   calls the generator", Dream-RSI's replay "reveals an outcome that has already been recorded".
   But Dream-RSI improves a search controller *over* a fixed harness, and Motoko's DST tests the
   harness — the loop, compaction, hooks, tool phase, approvals, clock — that Dream-RSI holds
   fixed. Dream-RSI's "lightweight orchestration layer" is, in Motoko's vocabulary, a harness,
   and it is untested by anything in the paper. §2, §3.2.
2. **Motoko already has a Dream-RSI-shaped loop, and it is stricter.** ADR-004 records a real
   session's journal as an execution program, strict-replays it under every candidate, refuses
   candidates outside an admissible class before they run, and does not score a replay whose
   observations diverge. That is Dream-RSI's replay world with one difference in kind: an
   out-of-support request is a **refusal** in Motoko and a **silent zero** in Dream-RSI. The
   other differences are of degree — ADR-004's objective is resource-shaped (D4: profiled
   allocation), Dream-RSI's is quality-minus-cost; ADR-004 has no policy-development agent and
   no selection over a candidate set. §3.1.
3. **The decisive asymmetry is replay-only versus generative.** Dream-RSI's trees are produced
   by stochastic live runs and cannot be regenerated; the "simulator pool" grows only by spending
   live agent calls. Motoko's world is a function of a seed: the record can be regenerated,
   widened and searched (D11), and the direction doc already names the need for "responsive
   simulated environments as well as replay". This is *why* Dream-RSI must restrict the policy's
   action space to recorded nodes — it has no other way to stay exact — and why Motoko's
   regression replay, which cannot restrict a changed harness's action space, fails closed
   instead. §3.2.
4. **Three things transfer.** (a) An offline evaluation of Motoko's *own* search scheduler
   against the corpus history D11 already requires every run to report — recovery branches
   reached per seed spent, which is the metric the direction doc proposes for comparing fault
   schedulers. (b) The incumbent-always-a-candidate selection rule, as a cheap floor for verifier
   transitions. (c) The prefix-only policy interface from Appendix B, which is a worked
   implementation of the direction doc's "a successor must earn acceptance against evidence and
   criteria it cannot rewrite during its own evaluation". §4.1–4.3.
5. **Four things Dream-RSI does not do that the direction doc treats as mandatory.** No verifier
   evolution (one improvable layer, everything else fixed by fiat). No in-support accounting (a
   policy that stops early or asks for unrecorded nodes is indistinguishable from one that
   searched well; the paper handles overfitting to "a frozen trace's known ceiling" by prompt
   discipline). No transfer test (policies are scored on the same history the development agent
   reads while revising them; the paper's own §5.1 shows offline-plausible guidance losing
   live). No reproduction contract for the online phase ("the transition is stochastic"). §3.3,
   §3.4, §5.
6. **One design idea falls out.** Classify ADR-004 candidates by whether their action space stays
   inside the recorded program. A candidate that only chooses *among* recorded outcomes (a
   compaction or elision policy over recorded messages) can be scored exactly by replay,
   Dream-RSI style, with no divergence possible. A candidate that changes what is requested
   needs fresh seeded discovery. Naming that split tells the runner which of D2's two replay
   modes a candidate is entitled to, before it runs. §4.2.

---

## 1. The source, compressed

### 1.1 The loop

Three stages per outer iteration *t* (paper Fig. 1, §3):

1. **Online explore.** Policy π_t guides a fixed *discovery agent* to build a discovery tree
   T_t; every attempt and its outcome is logged.
2. **Construct replay simulator.** T_t is appended to the history H_t = (T_1, …, T_t). Each tree
   is a "replay world"; the collection is the "simulator pool".
3. **Dreaming-based policy improvement.** A fixed LLM *policy-development agent* revises the
   policy code M times. Every version is scored on every tree in H_t by replay. The best average
   scorer becomes π_{t+1}. "Only the exploration-policy code is updated; the underlying models,
   evaluator, and execution interfaces remain fixed."

### 1.2 The formal objects

- **Tree.** Rooted at the task root *r* (initial workspace). Each non-root node *v* has one
  primary parent and records "the evolution history from *r* to *v* and the outcome of this
  single attempt, including the resulting filesystem snapshot, generated artifact, evaluation
  diagnostics, and score s_v".
- **The only action.** CONTINUE(v): resume v's workspace, generate and evaluate one new child.
  Eligible nodes A(T) = {r} ∪ leaves. A *batch* C ⊆ A(T) with |C| ≤ W (W parallel workers). One
  *decision round* = select a batch, observe its outcomes. C = ∅ terminates.
- **Online.** At most K_1 rounds. "The transition is stochastic because the discovery agent may
  generate different outcomes from the same workspace."
- **Replay.** Same decision interface over a fixed recorded tree T_i. The policy sees the
  revealed subtree and the legal-action set, never unrevealed outcomes. "The transition in the
  offline replay is deterministic to the child of the selected node." Child(v; T_i) **may be
  empty**. Terminates on empty batch, no recorded continuation remaining, or K_2 rounds. Every
  policy–tree pair replays from the root.
- **Replay objective** (eq. 1): V = max_v s_v − β_1·N + β_2·N / max{1, k}, i.e. best score
  attained, minus a per-attempt cost over N revealed nodes, plus a parallelism bonus (attempts
  per decision round).
- **Selection.** V^m = mean over trees. π_{t+1} = argmax_m V^m over m ∈ {0, …, M−1}, where m = 0
  is the incumbent. "Because the candidate set includes the current policy, this selection
  satisfies V^{m*} ≥ V^0" — the whole content of the "never worse" claim. It is a statement about
  average replay score on fixed history, not about live performance.

### 1.3 The policy interface (Appendix B, the policy-development prompt)

The prompt is the most concrete artifact in the paper and the one most relevant to Motoko's
evolving-verifier rules. Its load-bearing constraints:

- **Prefix-only.** "Decisions may use revealed observations, `baseline_score`, legal sets,
  structural `meta`, and helper signals. Never use unrevealed scores, a true optimum, hardcoded
  winning cell ids, absolute score targets, or internal trace data."
- **Two methods.** `solve(question, budget)` makes within-episode batch decisions from
  `question.observed()`; `plan_grid(context)` chooses branch count W and refinement depth R
  *before* a live episode and "must never inspect a current episode's outcomes".
- **Out of support.** "In replay, a requested plan beyond the frozen trace's
  `context.trace_branch_count` or `context.trace_refine_count` is out of support and cannot earn
  replay reward." No accounting of how often this happens is required or reported.
- **Between-round feedback only.** Replay traces (`policy_execution_traces.jsonl`) and the trace
  pool "may be read only outside `solve()`"; "never copy a trace-specific branch, cell id, score,
  or target into policy logic".
- **β has three roles and they must not be conflated**: fixed within an episode; swept on a grid
  during offline evaluation; chosen once as the baked-in default for the next live cycle from
  live evidence. "Do not select the default simply as the smallest beta that reaches a frozen
  trace's known ceiling."
- **"Never sample randomly."** The policy is required to be deterministic.

### 1.4 Results, briefly

Eight tasks, three domains, baseline = *Recursive Fixed Exploration* (same agent, evaluator,
initial "parallel refining" policy, per-round budget; policy never updated). Round-1 behavior is
identical by construction; divergence is from round 2 on.

| Domain | Setting | Result |
|---|---|---|
| Algorithm engineering (Lasso path) | Gemini-3.1 Pro, 5 rounds | 317 vs 550 agent calls; held-out runtime 2931 vs 3587 ms |
| | Gemini-3.7 Flash, 5 rounds | 1879 vs 3200 calls; 2351 vs 2517 ms |
| | vs SimpleTES (51,200 generations) | ~162× fewer calls, lower runtime |
| Math optimization (3 tasks) | Gemini-3.1 Pro, 10 rounds, <1k generations | Sum-Diff best of the table; Circle Packing ties the best; Autocorrelation competitive but behind SimpleTES |
| GPU kernels (KernelBench, 4 tasks) | Gemini-3.1 Pro | 2.43× / 1.79× fewer generations to parity; 2.09× / 1.44× higher score at equal budget |

Two analysis results matter more than the headline numbers for this note:

- **§5.1:** distilling history into "explicit semantic guidance" injected into the prompt
  "consistently underperforms its unguided counterpart across both paradigms under equivalent
  discovery budgets". History as an *interactive* replay world beats history as *advice*.
- **§5.2:** the learned policy's evaluated attempts per round went 110 → 110 → 87 → 80 → 50, then
  back up to 92 when progress plateaued — conserve while improving, spend when stuck.

### 1.5 What the paper does not cover

- Correctness of the orchestration layer itself. No invariants, no fault injection, no clock.
- Reproducibility of the online phase. Trees are stored; the run that produced them is not
  reproducible and is not claimed to be.
- Coverage or support accounting. Nothing reports what fraction of a policy's replay decisions
  were in support, or how much of each tree a candidate revealed.
- Held-out evaluation *at the meta level*. Downstream Lasso datasets are held out for the
  discovered *solver*; the *policy* is selected on the same H_t the development agent reads.
- Any change to the evaluator, the score function, the agent, or the prompt that revises the
  policy. All fixed.

---

## 2. Mapping onto Motoko

| # | Dimension | Dream-RSI | Motoko (HEAD `2062605`) | Where it lands |
|---|---|---|---|---|
| 1 | Object under improvement | Exploration-policy code over a fixed agent | The harness itself (DST); a candidate commit's resource behavior (ADR-004); the direction doc's three levels | §3.1, §3.2 |
| 2 | Recorded artifact | Discovery tree: attempts, snapshots, scores, diagnostics | `ExecutionProgram`: every provider / tool / approval / extension-effect / env / random / clock interaction, in causal order with identities and projections (D2) | §3.2 |
| 3 | How the record is made | Stochastic live runs of an LLM agent | A seeded generator answering the real driver's requests (D2, `dst_generator`); or a real session's journal, extracted (ADR-004 D1) | §3.2 |
| 4 | Can the record be regenerated? | No | Yes from (generator id, version, seed) for the generated axis; no for a journal-sourced program, by design | §3.2 |
| 5 | How the world grows | Spend live agent calls | Spend seeds (D11 rotating corpus); promote failures; admit journals (ADR-004 D6) | §4.1 |
| 6 | Candidate's action space in replay | Restricted by construction to recorded nodes; `Child(v;T)` may be empty | Unrestricted — the real driver runs; divergence is detected, not prevented | §3.2, §4.2 |
| 7 | Off-support request | "Cannot earn replay reward" — silent | `HarnessFailure` / `Diverged` / `Refused` — loud, unscored (D2; ADR-004 D3) | §3.1 |
| 8 | Oracle | Scalar: best score − β_1·attempts + β_2·parallelism | Structural invariants over the ledger trace, thirteen families (D7); "never over model prose". ADR-004 D4: profiled allocation, explicitly no quality claims | §3.4, §5 |
| 9 | Selection rule | argmax mean replay score, incumbent included | None yet at the level of "which successor"; ADR-004 yields per-candidate verdicts, not a ranking | §4.3 |
| 10 | Reproduction contract | None for the online phase | seed + program + manifest; strict replay requires identity match; corpus keyed on artifact identity *and* trajectory (`dst_corpus`) | §3.3 |
| 11 | Recorder self-check | None stated | Two-sided `class_balance` (under/over-recording); `reconstitution_balance`; `check_seed_sensitivity` | §3.3 |
| 12 | Coverage / vacuity accounting | Compute counts only | Computed vacuity register; one of forty classification entries substantive at the report's HEAD; anti-silent-drop count oracles | §3.3, §4.4 |
| 13 | Who owns the evaluator | Fixed by fiat | "An evaluator the candidate does not own" (ADR-004 title); protected closure pinned by exact-span hash (D5) | §3.1, §4.3 |
| 14 | What may evolve | Policy code only | Direction doc: execution, discovery *and* verification, with explicit standards transitions | §3.4 |
| 15 | Parallelism | W workers batch CONTINUEs inside one rollout; rewarded by β_2 | D9: simulator is single-actor; D11: parallel workers are search parallelism (`DST_JOBS`), not in-run concurrency | §5 |
| 16 | Position in the direction doc's related work | Would sit beside DGM, Hyperagents, Havoc as a fourth adjacent starting point: the *discovery-level* instance | §3.4 |

---

## 3. Where the ideas land

### 3.1 ADR-004 is already Dream-RSI-shaped, with a stricter refusal and a different objective

ADR-004's one-line contract — "a session journal is an evaluation source: an execution program
recorded from its replay at admission, strict-replayed by every candidate, graded by an
evaluator the candidate does not own" — is structurally the Dream-RSI loop with the tree replaced
by a linear interaction program:

| Dream-RSI | ADR-004 |
|---|---|
| Online rollout produces T_t | A real session's journal + host log |
| Tree appended to H_t | D1 extraction → D2 admission run records the program at schema `/4` with a manifest |
| Candidate policy replays T_i from the root | Candidate commit strict-replays the program (D3: preflight, `world_state_of`, `reconstitution_balance`, `strict_replay_findings`, `check_discovery`, thirteen families) |
| Replay reveals stored outcomes | Replay serves recorded outcomes to the candidate's real driver |
| Score V (eq. 1) | Verdict `Reproduced` / `Diverged { location, finding }` / `Refused`; D4 claim on profiled allocation |
| Out of support ⇒ zero reward | "A replay whose observations diverge is not scored"; "a candidate outside the class is refused before it runs" |
| Policy may not read unrevealed outcomes | D5: protected closure in candidate files, pinned by exact-span hash, with a checker |
| Simulator pool | D6 corpus: snapshot + excerpt + selector + program + expectations + identities |

Three differences, in order of importance:

1. **Refusal versus silence.** This is a difference in kind. Dream-RSI's policy that asks for an
   unrecorded continuation simply gets nothing and the episode continues; its score is lower,
   and nothing distinguishes "the policy chose to stop" from "the tree ran out". ADR-004's
   candidate that diverges is *not scored*, with a location and a finding. Motoko's choice is
   the right one for a verification loop and would be the wrong one for Dream-RSI's optimization
   loop — an optimizer *wants* to keep scoring partial trajectories. The two loops want different
   things from the same mechanism, and that is the cleanest statement of how they differ.
2. **Objective.** ADR-004 D4 is deliberately resource-shaped: "cumulative profiled allocation …
   primary; GC, live heap, RSS and recursion depth secondary; no task-quality, latency or
   provider claims." Dream-RSI's is quality-minus-cost. Motoko *could* attach a quality term to a
   journal replay — the journal has the real model's real outputs — but the direction doc's
   caution applies verbatim: replaying an old response against a changed request is not evidence
   of the new behavior's quality. Dream-RSI sidesteps that caution because its candidates never
   change the request (§3.2).
3. **No development agent, no ranking.** ADR-004 produces a verdict per candidate; nothing
   revises candidates from replay feedback, and nothing selects among a set. That is a gap
   Dream-RSI fills cheaply (§4.3), and it is the gap the direction doc's "Discovery" level is
   about.

The practical upshot: **Motoko does not need to build a replay world to start on Dream-RSI's
idea. It needs to add a selection loop on top of one it already has** — after ADR-004 lands its
D8 gate, not before.

### 3.2 Replay-only versus generative, and why Dream-RSI must restrict the action space

Both systems are "exact over what was realized". The difference is what *realized* means.

Dream-RSI's tree is realized once, by a stochastic agent, and can never be extended offline.
Every replay decision must therefore land on a node that exists. The paper achieves exactness by
making that structural: the *only* action is CONTINUE(v) over eligible recorded nodes, a batch
is a subset of them, and a leaf with no recorded child is a dead end. The policy's freedom is
confined to *which subset, in which order, with which batching, stopping when* — the four
degrees of freedom the abstract lists. Nothing else is expressible, so nothing else can diverge.

Motoko's generated-axis record is realized by a seeded world answering the real driver, and D2
insists the world "chooses only at requests the real driver actually makes". The candidate under
regression replay is the *driver*; its action space is whatever the changed code does. Motoko
cannot confine that to recorded nodes without rewriting the candidate, so it does the only other
thing: detect divergence at the identity level and fail closed ("a wrong kind/origin, unsafe
identity mismatch, exhausted program, or unused interaction is a `HarnessFailure`").

What Motoko has that Dream-RSI structurally lacks is the *generator*. A diverging candidate on
the generated axis can be sent back to discovery at the same seed — the world is responsive,
not just recorded — and the result is a new program that is exact for the new candidate. The
direction doc names this: "Evaluation therefore needs responsive simulated environments as well
as replay." Dream-RSI's simulator pool cannot answer a question its trees did not record, and
the paper's "zero-execution-cost" claim is true precisely *because* no such question can be
asked.

This also reframes the paper's §5.1 result. Semantic guidance lost to replay because guidance is
history *compressed*, and replay is history *queried*. Motoko's generated axis is history
*regenerated*, which is a third thing, and there is no experiment in the paper about it.

### 3.3 Both recorders have the same blind spot; only one names it

`src/core/dst_replay.ail`'s header states the weakness strict replay is built against: "strict
replay compares recorded against actual, and if both sides derive from the same defective
projection they agree." The module answers with `reconstitution_balance`, and `dst_discovery`
answers the recorder side with a two-sided `class_balance` that reports both under-recording and
over-recording from one arithmetic site.

Dream-RSI's tree recorder has the identical exposure and the paper does not mention it. A tree
that silently drops an attempt (a worker crash, an evaluator timeout not written back) yields a
replay world that is consistent, deterministic, and shorter than the run that produced it. Every
candidate policy replayed on it agrees with every other; the missing branch is invisible to the
score; the selected policy may be the one that happened not to need it. The Appendix B prompt's
insistence on not reading `question.best_so_far` or `budget_spent` for decisions is about a
different leak (bookkeeping as oracle), not this one.

The same applies to the seed-sensitivity family. `dst_generator`'s `check_seed_sensitivity` exists
because "a generator that ignores its seed is MORE reproducible, not less", and the check is
content-shaped because site 19 showed a count is blind to two programs of equal length and
different contents. Dream-RSI's selection is count-shaped in one term (N revealed nodes) and
max-shaped in the other (best s_v); a policy that reveals the same *number* of nodes as the
incumbent but a different *set* is distinguishable only if the max differs. That is fine for an
optimizer and would be disqualifying for a verifier.

So the transfer is one-directional here: Dream-RSI has nothing to teach Motoko about recorder
integrity, and Motoko's anti-vacuity machinery is a checklist any borrowed replay-scoring
mechanism must pass (§6).

### 3.4 "Never worse" is a selection tautology; the direction doc's transfer rules are the other half

V^{m*} ≥ V^0 follows from including the incumbent in the argmax. It says the selected policy is
no worse *in mean replay score on H_t*. Three things it does not say, each of which the direction
doc already requires:

- **Not out of sample.** The development agent reads replay traces from H_t between revisions
  and the selection is on H_t. The direction doc: "Fresh seeds alone are insufficient evidence of
  generalization when they sample the same narrow environment model. Withhold fault families or
  implementations where practical."
- **Not live.** Round-over-round live improvement is shown empirically (Fig. 3b, Fig. 6), which
  is evidence, but no per-transition live check gates deployment. The direction doc: "assess
  whether gains survive live execution" and "report uncertainty rather than selecting one
  successful lineage."
- **Not about the verifier.** β_1, β_2, the evaluator, and the agent are fixed, so the question
  "did the measurement weaken?" cannot arise. The direction doc spends most of its length on
  exactly that question because Motoko intends to let the verifier evolve. Dream-RSI is a
  clean example of the *easy* case — one improvable layer, everything above it frozen — and it
  is worth being explicit that its guarantee does not survive unfreezing anything.

In the direction doc's three-level table, Dream-RSI is a working, published instance of the
**Discovery** row ("more useful improvements discovered under a fixed resource budget"), with
Execution fixed and Verification fixed. That makes it the natural fourth entry in the doc's
related-work list, next to DGM (execution level, self-modifying code), Hyperagents (the
improvement procedure), and Havoc (DST for tool failures).

### 3.5 Smaller landings

- **β as a fixed-per-episode schedule, chosen once per cycle from live evidence** is the same
  discipline as Motoko's execution manifest: configuration pinned before the run, never adapted
  from observations inside it, with a recorded reason. The three-roles rule ("never change beta
  from observations inside `solve()`") is D8's "the program records the manifest it ran under"
  seen from the policy side.
- **"Between-round feedback only"** — replay traces readable outside `solve()`, never inside — is
  a two-phase version of ADR-004 D5's protected closure. Motoko pins by hash; Dream-RSI pins by
  prompt. Motoko's is checkable; Dream-RSI's is not.
- **The simulator pool is D11's corpus** with the roles reversed: D11 keeps failures (promoted
  regressions) and rotates seeds; Dream-RSI keeps every tree and rotates policies.
- **The parallelism bonus** rewards batching CONTINUEs within one rollout. Motoko's D9 keeps the
  simulator single-actor and D11 makes parallelism a property of the *search*, not the run. If
  Motoko ever scored a scheduler on throughput, the analogue of β_2 would be seeds per wall-clock
  under `DST_JOBS`, not concurrency inside a program.

---

## 4. Concrete candidates

None decided. Ordered by how little new machinery each needs.

### 4.1 Score Motoko's own search scheduler offline against corpus history (D11)

D11 already requires every run to report generator id/version, attempted seeds, completed
`SystemRun` count, harness/generator failures, **fault classes reached**, **named recovery
branches reached**, waived classes, terminal reasons, and elapsed budget. That is a discovery
tree in all but shape: one node per (seed, profile) with its realized yield.

A *search policy* — which seeds, which profile, which fault families next, when to stop a
window — can be scored against that history exactly as Dream-RSI scores an exploration policy:
replay the policy over the recorded window, reveal only the yields of the seeds it chose, and
score branches-reached per seed spent (the direction doc's "defects found per compute budget",
with branches as the count D11 says is the one that matters). The incumbent — D11's
date-derived rotating window — is always a candidate, so the floor is free.

What it needs that does not exist: a durable per-run yield record keyed the way `dst_corpus`
keys members (artifact identity *and* trajectory), and a definition of "in support" for a policy
that asks for a seed the window never ran (§4.4). What it does not need: any change to the
driver, the world, or the invariants.

What it would show: whether Motoko's rotating window is leaving yield on the table — e.g.
whether seeds that reach a waived class are being re-run, or whether a fault family that has
never reached its recovery branch is being under-sampled. Fig. 6's pattern (spend less while
yield is rising, more when it plateaus) is a plausible first learned behavior.

### 4.2 Split ADR-004 candidates by action space, and give each split its replay mode

Dream-RSI is exact because its candidates cannot leave the recorded tree. Some Motoko candidates
have the same property and are not currently distinguished from those that do not:

- **Inside the program.** A compaction tier policy, an elision rule, a checkpoint-chain
  validator, a tool-result truncation change: these choose *among* recorded messages and
  outcomes and never alter what is requested from the world. Under D2's strict replay they
  cannot diverge at the identity level; every recorded interaction is consumed in order. They
  can be scored exactly, Dream-RSI style, on every program in the corpus, and a quality-shaped
  term is defensible because the request never changed.
- **Outside the program.** A prompt change, a tool-catalogue change, a new hook that performs an
  effect: these change requests, so recorded outcomes stop being evidence. They need fresh
  seeded discovery (generated axis) or a new admission (journal axis), and D2's *regression*
  replay mode with projection differences recorded.

ADR-004's "admissible class" already refuses some candidates before they run. This candidate
proposes naming the *inside-the-program* subclass explicitly, so that the runner knows before
starting which mode a candidate is entitled to and which claims (D4's resource claims only, or
resource plus a bounded quality term) its verdict may carry. This is the one place where
Dream-RSI's restriction is a design tool for Motoko rather than a limitation.

### 4.3 A prefix-only interface for the first evolving verifier component

The direction doc's first convincing demonstration (§"A first convincing demonstration") ends
with a successor that "uses the improved process to discover and repair additional unseen
defects more effectively than its parent", and its evolving-verifier section names the fault
scheduler as the worked example. Appendix B is a ready-made shape for that component:

- a `plan` method that runs *before* a window and may read only completed history;
- a `solve` method that runs *inside* a window and may read only the revealed prefix;
- a hard rule that between-round diagnostics are never read inside `solve`;
- a fixed-per-window scalar (β) whose next default is chosen from live evidence, never from
  inside a run;
- "never sample randomly" — the scheduler is deterministic given the prefix, so its choices are
  themselves replayable.

Motoko would enforce the prompt's rules mechanically — AILANG's effect rows already make "may not
read X inside Y" a type-level statement, and ADR-004 D5's hash-pinned closure already makes "may
not edit the evaluator" checkable — which is the part the paper leaves to instructions.

### 4.4 In-support ratio as a mandatory line in any replay-scored verdict

Dream-RSI reports nothing about how much of each tree a policy revealed or how often it asked
for an unrecorded continuation. The Appendix B warning against picking "the smallest beta that
reaches a frozen trace's known ceiling" is the symptom: the ceiling is the *tree's*, not the
policy's, and a score cannot tell them apart.

Motoko's vacuity discipline (the report's §6; `check_no_op_profile.py`; the computed one-of-forty)
is the mechanism Dream-RSI lacks. Any Motoko use of replay scoring — §4.1, §4.2 — should carry a
computed, not asserted, statement of the form: *N of M decisions were in support; the candidate
revealed K of R recorded interactions; the score's max term was attained at a node the
incumbent also revealed / did not reveal.* A verdict without that line is the frozen-ceiling
problem re-imported.

### 4.5 Held-out fault families for the first RSI experiment

The paper holds out downstream datasets for the *discovered solver* and nothing for the
*policy*. The direction doc already asks for the opposite: "Withhold fault families or
implementations where practical." ADR-004 D8's "held-out process" is the same idea one level
down. This candidate is only a reminder that when §4.1's scheduler is scored, the corpus window
it is scored on must not be the window its development read — or the "never worse" floor is the
only guarantee that survives.

---

## 5. What does not transfer

- **The scalar oracle.** Dream-RSI's whole mechanism is a number to maximize. Motoko's DST
  oracle is a set of invariants that are each their own constructor precisely so that a suite
  cannot pass on "a non-empty finding list" (`dst_invariants` header). Importing a scalar as the
  *acceptance* signal for a harness change would undo that; importing it as a *ranking* among
  candidates that all pass the invariants is §4.3.
- **The tree as the unit.** Motoko's unit is a causally ordered interaction program, linear per
  run. Branching lives across runs (seeds), not within one. Dream-RSI's within-run branching is
  the *discovery* structure of a search problem, not a property of the harness, and there is no
  reason to import it into the world.
- **"Zero execution cost".** Motoko replay runs the real driver against the world; it is
  deterministic, not free. The paper's cost claim is about *not calling the agent*, which
  Motoko's replay also achieves, but the driver's own cost is exactly what ADR-004 D4 measures.
- **The fixed-agent assumption.** Dream-RSI leaves "the underlying coding agent unchanged".
  Motoko's candidates *are* changes to the machinery around the model. The paper offers no
  guidance for that case and its guarantee does not extend to it.
- **Growth by live runs.** Dream-RSI's pool grows only when a live rollout is paid for. Motoko's
  generated axis grows by seeds. Where the paper reasons about how many live rounds to run,
  Motoko reasons about seed budgets, and the economics are different enough that its round
  counts do not carry over.
- **In-run parallelism.** D9 keeps the simulator sequential; β_2 has no analogue inside a
  program (§3.5).

---

## 6. Risks

1. **Overfitting the scheduler to the corpus.** The paper's own frozen-ceiling warning, one level
   up. Mitigation is §4.4 (in-support accounting) plus §4.5 (held-out windows); without both, a
   learned scheduler that merely replays last month's winners will score perfectly.
2. **The recorder blind spot transfers with the mechanism.** A yield record that drops a run makes
   every scheduler agree. §4.1's record must pass a two-sided balance against D11's reported
   counts the way `class_balance` does, or it is the recorder grading itself.
3. **Branches-reached is count-shaped.** Site 19 again: two windows reaching the same *number* of
   recovery branches, different *sets*, are indistinguishable to a count. Any §4.1 score must be
   over the set, not its size.
4. **Sequencing.** Per `HANDOFF-2026-09-17-plan004-post-p1g-p22-blocked.md`, PLAN-004 stands at
   P1 and P2.1 done, P2.2 blocked on an operator directive, P3–P5 queued; ADR-004's D8 gate is
   in the queued part. §4.1–4.3 are follow-ons to that gate, not alternatives to it. Starting a
   selection loop before the thing it selects over exists would be the meta-level version of
   the fixture-only invariant suite `dst_execution`'s header describes.
5. **Mechanism claims are from a prompt, not code.** Appendix B is the runner's *instructions* to
   the development agent; the runner that enforces them is unreleased. Where this note says
   "Dream-RSI requires X", read "the prompt tells the agent X". Re-check against the repository
   when it is public.
6. **Attribution and priority.** The direction doc explicitly makes no priority claim, and this
   note follows it. "History is already a simulator" is Dream-RSI's phrase. ADR-004 (v1
   2026-09-13, v5 Accepted 2026-09-15) arrived at the same shape with no reference to the paper
   — nothing in `.agent`, `design_docs`, `papers` or `src` mentioned Dream-RSI before this note
   — and the paper's latest accessed reference is dated 2026-08-13, so the two are
   contemporaneous. A convergence, not a borrowing in either direction; describe it as such if
   the report is ever revised.

---

## 7. Candidate follow-ons (none decided)

1. Add Dream-RSI to the direction doc's "Position among related work" as the discovery-level
   instance, with the one-sentence distinction from §3.4 (one improvable layer; verifier fixed
   by fiat; guarantee is in-sample). Smallest possible change; no decision implied.
2. After ADR-004 D8 lands: a NOTE measuring how many corpus candidates to date fall in the
   *inside-the-program* subclass of §4.2, from the existing `Reproduced` / `Diverged` verdicts.
   If it is most of them, §4.2 is a cheap admission-time classification; if it is few, it is not
   worth naming.
3. After D11's rotating corpus has a durable per-run yield record: a scratch replay of the
   incumbent window policy against its own history, reporting the §4.4 in-support line. This is
   the "does the mechanism run at all on our data" probe, with no candidate policies yet.
4. A one-page sketch of the fault scheduler as the first prefix-only component (§4.3), written
   against the direction doc's "first convincing demonstration" and ADR-004 D5's closure rules,
   so that the RSI experiment's Verification-level candidate has a shape before anyone builds it.
5. Re-read the paper's repository when released, with two questions: how the runner detects and
   reports out-of-support requests, and whether anything checks the tree recorder. Both answers
   change §3.3 and §4.4.
