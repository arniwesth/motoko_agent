# RESEARCH: System One models (TypeSafe AI, Jev) — a decision function behind the hooks, not a solver

Date: 2026-09-18
Status: Research note (no decision taken; candidate follow-ons listed in §7)
Grounded at: branch `arniwesth/013-plan003-and-herdr`, HEAD `2062605`; AILANG `v0.33.0`
Sources:
- Diogo Almeida (TypeSafe AI), *Introducing System One Models and Jev* —
  typesafe.ai/blog/introducing-system-one-models-and-jev. Read through a summarising fetch, not
  the raw page; every number below is one the fetch returned verbatim.
- github.com/typesafe-ai/system-one-adapter-python — the Python "System One LLM adapter": a
  drop-in for `typesafe_sdk`'s `system_one` call backed by an ordinary LLM. The only place the
  call shape is documented publicly. The `typesafe_sdk` itself, its wire format and its auth
  were **not** inspected; the article does not publish them.
- console.typesafe.ai (playground) and evals.typesafe.ai — not visited.

Relates to:
- `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` — policy at the per-step
  decision points lives on the extension side of `ExtensionHooks`; core keeps mechanism and a
  safety floor that holds with zero extensions loaded. Every landing in §3 is on the extension
  side of that seam, and §5.1 is about why the floor must not move.
- `../005_harness_policy_boundary/PLAN-empty-stop-guard.md`,
  `PLAN-progress-contract-guard.md`, `HANDOFF-write-persist-nudge-migration-plan.md` — the
  three finalize guards. §3.1: they are the first place a decision model would replace a
  hand-written heuristic.
- `src/core/recovery.ail` — `any_writefile_attempt` (l.40), `should_inject_persist_nudge`
  (l.59), `persist_nudge_message` (l.63): the heuristic and the canned feedback it emits. Also
  `should_retry_stream_error` (l.23), the shape §3.5 wants every threshold to take.
- `packages/motoko-ext-abi/types.ail` — `ToolPolicyDecision` (l.637), `FinalizeDecision`
  (l.652), `PreStepDecision` (l.665), and `ExtPorts.ai_step` (l.294), the port an extension's
  model call already goes through.
- `src/core/ports.ail` — `RequestClass` (l.522) and `Ports.model_step` → `ProviderExchange`
  (l.886): the recorded-exchange pattern a decision port would copy. §3.5.
- `../013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md` (v4) — D4 (no
  task-quality claims at T0), D6 (corpus private, `0700`, scanned). §3.6 and §6.
- `../021_herdr_delegation/DESIGN-delegate-model-selection.md` §2.3, §5 — "a bogus model starts
  successfully"; the allowlist argument. §3.4.
- `../028_verified_runtime_closing_the_loop/NOTE-007-the-loop-that-would-not-stop.md` — 197
  steps of one cycle; the shape of the no-progress question in §3.3.
- `../028_verified_runtime_closing_the_loop/ADR-001-fail-closed-verification-everywhere.md` —
  the posture an unreachable or low-confidence decision service inherits. §5.1.
- `../027_z3_contracts/ADR-001-contract-classification-register.md` — where the pure
  threshold functions of §3.5 would be registered.
- `../026_operational_ontology/RESEARCH-operational-ontology-implications.md` §3.1 — refusal
  codes at `ToolPolicy`. A decision model's answer would be one input to that gate, not the
  gate.
- `../016_github_ops/ADR-001-github-pr-ops-pipeline.md`,
  `../022_linear_integration/RESEARCH-linear-integration.md`,
  `../015_idea_factory/RESEARCH-idea-factory-and-idea-evaluation.md` — the rank/classify/score
  surfaces outside the step loop. §3.7.
- `.motoko/ab/` — the existing A/B answer files; the harness a §4.1 comparison would reuse.

---

## 0. TL;DR

TypeSafe's claim: a "System One model" is a frontier model that gives up string generation and
returns **typed structured values with calibrated probabilities**, all questions answered in
parallel, in 70–500 ms end to end, at $0.042 per million input tokens with output free. Jev is the
first one. The call is `system_one(state, questions)`: unstructured or program state in, a
dictionary of named `Noul` / `Score` / `Choice` answers out, each with a probability. A `Choice`
carries at most 255 options. It is a waitlist beta with a Python SDK.

Read against HEAD `2062605`:

1. **Motoko's hook decisions are already the output type Jev produces.** `FinalizeDecision`,
   `ToolPolicyDecision`, `PreStepDecision` are closed sums of three or four arms. Jev is a
   function from a state blob to a closed sum with a probability attached. The fit is exact at
   the type level and nowhere else: Jev cannot write a message, a tool argument or a summary, so
   it cannot be the solver and cannot be a compactor that summarises. §2.
2. **The first landing is the finalize guard.** The three guards in 005 are hand-written
   heuristics over the transcript — a `WriteFile` name match, a marker substring, a blank-content
   check. "Does this candidate complete the task?" is a proposition with a probability, and
   `ContinueWithFeedback(persist_nudge_message(...))` already emits canned text, which is what a
   non-generating model forces. §3.1.
3. **A decision call is a nondeterministic network effect and must be a recorded port.** The
   article makes no determinism claim; assume none. The call goes through a port that writes an
   exchange record — `model_step` → `ProviderExchange` is the template — and the probability
   becomes a journaled observation. Strict replay then reproduces the decision without the
   service. §3.5.
4. **The probability-to-decision step stays pure and contracted.** `should_retry_stream_error`
   already has `ensures { not result || (remaining_step_budget > 1 && retryable) }`. A threshold
   function `ensures { not allow || p_safe >= floor }` is the same move. The model's opinion is
   data; the policy that acts on it is a checked function. This is the one architectural gain
   that does not depend on Jev being any good. §3.5.
5. **The two headline claims are narrower than they read.** "0% hallucination" means the output
   always matches the schema; a well-typed `Allow` can still be wrong. "Calibrated" is measured
   against the averaged probabilities of the two largest external LLMs, not against ground truth.
   Motoko has ground truth for its own decisions — type-check, tests, whether an accepted stop
   survived verification — and can measure the service itself. §5.2, §6.
6. **Nothing here needs Jev to start.** The adapter documents the call shape, and a small LLM
   under constrained output is the adapter's own backend. Build the decision port and the first
   guard against `system_one(state, questions)` now; swap the backend when early access lands
   and compare on the same recorded decision points. §4.1.

---

## 1. The source, compressed

### 1.1 What is claimed

- **Class.** "Fast, structured decisions that software can use directly." Contrast: an LLM
  samples a flexible string token by token; a System One model outputs "type-safe structured
  values" with calibrated confidence, in parallel.
- **Jev.** "A frontier-intelligence function call: unstructured state in, typed probabilistic
  decisions out." Gives up string generation. Positioned for: classify, route, score, extract,
  branch; map-reduce over large datasets; real-time paths; "score, judge, verify, guardrail, and
  detect jailbreaks of LLM prompts, reasoning traces, and/or outputs."
- **Numbers.** 70–500 ms end to end, "40x–200x faster" than frontier LLMs on comparable tasks;
  $0.042 / M input tokens, output free. Cardinality up to 255 per choice; above that, a two-stage
  scheme. Text only ("not on images (yet…)").
- **Stack.** A new architecture (undisclosed), a parallel sampler, and **RLCD** — reinforcement
  learning for calibrated decisions — in place of RLHF/RLVR: the objective is "epistemically
  honest probabilities," not preference or verifiable correctness.
- **Evals.** "Workflow evals": assume a correct compute graph exists in code, ask the model the
  decomposed questions at each branch, and score against "the average of GPT-6 Astra and
  Fable 5.1 as the reference answer." Two demos: a side-by-side against GPT-5.6 Terra, and
  Wikiracing (hundreds to thousands of link choices per step). Authors flag: workflows written by
  their own capabilities team, results "on the higher end of real world gains," benchmarks "from
  our laptops on the West Coast," comparison biased toward OpenAI/Anthropic models.
- **Availability.** Early access from a waitlist; pre-commercial beta; pricing published with
  the admission that they cannot prove it is not subsidised.

### 1.2 The call shape (from the adapter)

```python
from system_one_adapter import SystemOneAdapterClient, Noul, Score, Choice

client = SystemOneAdapterClient(structured_outputs=True,
                                llm_answer_mode="probabilities",   # or "discrete"
                                normalize_probabilities=True)

response = client.system_one(
    state="This book was a delight to read.",
    questions={"positive": Noul(instructions="The book review is positive.")},
    provider="openai", model="gpt-4o-mini",
)
```

- `state` is the blob the questions are asked of. The article stresses "structured program
  state" over free text.
- `questions` is a dict of named question types. `Noul` takes a proposition and returns its
  probability. `Score` and `Choice` are the scalar and the enumeration. The exact semantics of
  the name `Noul` are not documented in what was read.
- The adapter's `response.usage` carries `n_retries_malformed_structure`; that field exists
  because an LLM under constrained output still returns malformed structure sometimes, and Jev's
  claim is that its sampler cannot.

### 1.3 What the article does not say

No wire format, no auth, no rate limits, no context window, no determinism or reproducibility
claim, no data-retention statement, no latency distribution (the 70–500 ms band is the only
figure), no open weights.

---

## 2. Mapping onto Motoko

| # | Motoko seam | Today | With a decision model | Fit |
|---|---|---|---|---|
| 1 | `on_solver_candidate` → `FinalizeDecision` | Empty-stop check, `any_writefile_attempt`, marker count (005, `recovery.ail`) | `Noul` questions over the candidate + task: completes task; required artefact missing; claims unrun work | Exact type fit; feedback must be canned |
| 2 | `on_tool_policy` → `ToolPolicyDecision` | Extension allowlists; `Pending(reason, default)` design (`m-motoko-tool-policy-pending.md`) | A `Score` for risk, banded to Allow / Pending / Deny | Latency fits the tool path; floor must not depend on it |
| 3 | `on_pre_step` → `PreStepDecision` | Compactor chain; the `keep_last=3` failure in 005's context | Per-message keep/elide `Choice`, map-reduced across the history | Selects; cannot summarise |
| 4 | Delegate model choice (021) | Passthrough; a bogus model starts fine (§2.3) | `Choice` over the allowlist; the allowlist is the schema | Exact; ≤255 options |
| 5 | No-progress detection (028 NOTE-007) | The loop guard NOTE-007 added | A `Score` for "last N steps repeat without progress" | New signal, same guard |
| 6 | PR / Linear comment triage (016, 022, `pr-review-loop`) | Ranking by the agent itself | Rank + classify as `Choice`/`Score` per comment, in parallel | Classic use; outside the step loop |
| 7 | Idea scoring (015) | LLM judge | `Score` per idea per criterion | Cheap enough to score every idea every time |
| 8 | ADR-004 evaluator, task-quality tier | Out of scope at T0 (D4) | A grader over journal segments | Blocked by D6 privacy until scanned; §3.6 |
| 9 | Solver step, tool arguments, summaries, commit messages | LLM | — | **Does not fit**: no string generation |

Rows 1–5 are inside the step loop and inherit the port discipline of §3.5. Rows 6–8 are batch
work where the per-call price is what matters.

---

## 3. Where the ideas land

### 3.1 The finalize guard is the first landing, and it is already shaped for a non-generating model

The three 005 guards decide one thing: is this `"stop"` a substantive completion? Today the
inputs are structural — blank content and no tool calls; whether any `WriteFile` call appears in
the history; how many `[motoko-persist-nudge]` markers a user turn contains. These are proxies
for a semantic question, chosen because the semantic question had no cheap, typed answer.

A decision model answers the semantic question directly. The `state` is the task text plus the
candidate plus a bounded slice of the transcript; the `questions` are propositions:

- `completes_task` — the candidate does what the task asked.
- `artefact_missing` — the task required a file and none was written.
- `claims_unrun_work` — the candidate asserts results (tests pass, build green) that the
  transcript does not show being run.
- `is_question_back` — the candidate is a question to the operator, not a completion.

The `FinalizeDecision` arms then follow from bands over those probabilities, and the feedback in
`ContinueWithFeedback` is a fixed template per question — which is exactly what
`persist_nudge_message` is today. The model's inability to write prose costs nothing here: the
guard was never supposed to be creative.

What changes for 005's plans: the persist-nudge migration (`HANDOFF-write-persist-nudge-migration-plan.md`)
moves the heuristic to the seam; this note says the seam can then swap the heuristic for a
question without touching the seam again. The empty-stop safety floor in core stays a structural
check and does not learn about any of this (§5.1).

### 3.2 Tool policy gets a graded input, not a new gate

`ToolPolicyDecision` already has the three bands a calibrated score wants: `Allow`, `Pending(reason,
default)`, `Deny(reason)`. A risk `Score` over the command, cwd and recent history maps onto them by
two thresholds. What 026 §3.1 asks for — machine-readable refusal codes — is unaffected: the code
names *which question* tripped (`RISK_DESTRUCTIVE_FS`, `RISK_NETWORK_EGRESS`), and the probability
goes in the ledger beside it.

The 70–500 ms figure is what makes this a candidate at all. The same question asked of a frontier
LLM through the adapter path is "slower and more expensive" by TypeSafe's own account, and would
not be asked on every tool call.

### 3.3 No-progress detection becomes a question instead of a pattern

NOTE-007's loop — open pane, sleep, read, close, 197 times — was caught by a guard that recognises
that pattern. The general form is "the last N steps did not advance the task," which is a `Score`
over a window of the transcript. This is the same input shape as §3.1 with a different question,
and it should be one extension, not two.

### 3.4 Delegate model choice: the allowlist becomes the schema

`DESIGN-delegate-model-selection.md` §2.3 found that herdr starts an agent on `claude-opus-9-turbo-BOGUS`
with `exit 0` and `interactive_ready: true`, and §5 argues for an allowlist rather than a
passthrough. A `Choice` whose options *are* the allowlist makes the bogus model unrepresentable at
the point the choice is made, and returns a probability per option, so the operator-facing view
(dagr) can show why a delegate got a cheap model. Cardinality is not a concern: the allowlist is
tens of entries, not hundreds.

### 3.5 Every call is a recorded port, and the threshold is a contracted pure function

This is the load-bearing section.

**The port.** Motoko's DST substrate (ADR-003/ADR-004, `ports.ail`) requires that every
nondeterministic input enter through a port that writes a record and that strict replay
reproduces from the record without the world. `Ports.model_step` returns a `ProviderExchange`;
`RequestClass` enumerates `EnvRead | FileRead | ClockRead | ToolExec | ModelStep | WakeRead`. A
decision call is a seventh class or a variant of `ModelStep`: request = (state digest, questions),
response = (answers, probabilities, latency, model id). The extension side already has one model
port, `ExtPorts.ai_step` (`types.ail` l.294), and its `AiStepOutcome` carries the successor world
token; a `decide` port would sit beside it with the same threading discipline.

Two consequences:

- **Replay is Jev-free.** An admission run records the exchange; every candidate replays the
  recorded probabilities. ADR-004 D3's strict-replay findings apply unchanged. The service's
  nondeterminism — if any — is quarantined to the recording run.
- **The threshold is verifiable.** The function from probabilities to `FinalizeDecision` is
  pure. It takes the shape `recovery.ail` already uses:

  ```
  export pure func finalize_from_scores(p_complete: int, p_missing: int, floor: int, ceiling: int) -> FinalizeDecision
    ensures { result != Accept(_) || (p_complete >= ceiling && p_missing < floor) }
  ```

  (scores as basis points, to stay in `int`.) That is a candidate for the 027 register, and it
  is the property an example cannot state: for *every* score vector, `Accept` implies the
  scores cleared the bar. The model can be wrong; the policy cannot be inconsistent with its
  stated thresholds.

**The DST generator.** Because the decision port is a `RequestClass`, `dst_generator.ail` can
script its answers: a profile that returns `p_complete = 0.51` on every candidate exercises the
band edges without a network. This is the property-test surface for the guard, and it exists
before any service is reachable.

### 3.6 ADR-004's evaluator could grow a task-quality tier, but not yet

ADR-004 D4 excludes task-quality claims at T0 by design — the evaluator measures allocation and
replay fidelity, not whether the agent did a good job. A decision model priced at $0.042 / M
input makes grading every corpus entry on every candidate affordable: "did the accepted stop
complete the task," "did the agent read the file it edited," asked of the journal segment. That
is a T2-or-later tier, and two things block it now: D6 makes the corpus private and scanned, and
sending journal excerpts to a third-party beta endpoint is an exposure the corpus's exposure log
would have to record and the scan would have to clear first (§6). A grader that runs locally
through the adapter path has neither problem and is the honest first version.

### 3.7 The batch surfaces are the boring, safe wins

PR comment triage (016, `pr-review-loop`), Linear intake (022), and idea scoring (015) are
rank/classify/score over independent items — the map-reduce case the article leads with. None sit
in the step loop, none touch the floor, and all are already LLM calls today. They are the places
to learn the service's calibration cheaply before trusting it anywhere in §3.1–3.4.

---

## 4. Concrete candidates

### 4.1 A decision port and a finalize guard, backend-agnostic

- Add a `decide` port to `ExtPorts` beside `ai_step`: `(ExtWorld, state: string, questions:
  [Question]) -> DecideOutcome ! {AI, IO, Trace}`, with `Question = Noul(name, instructions) |
  Score(name, instructions) | Choice(name, instructions, options: [string])` and answers as basis
  points. Record the exchange as a new `RequestClass`.
- Implement `on_solver_candidate` in a `motoko_ext_finalize_guard` extension that asks the §3.1
  questions and maps through a contracted pure function (§3.5). Canned feedback per question.
- First backend: the adapter's approach — a small model under constrained output through the
  existing provider path. Second backend: Jev, when early access lands.
- Measure both on the same recorded decision points from real sessions; the ground truth is
  whether the accepted stop passed verification (DP7 / tests) downstream. Reuse `.motoko/ab/`.

This is the whole of the near-term proposal. Everything below is contingent on its numbers.

### 4.2 A risk score at `on_tool_policy` (contingent on 4.1's latency and calibration)

Same port; a `Score` per call banded to `Allow / Pending / Deny`; refusal codes per 026 §3.1.
Only worth doing if 4.1 shows the service's calibration holds on Motoko's own transcripts, and
only in profiles where autonomous approval is on.

### 4.3 A `Choice` over the delegate allowlist (021)

Small, independent of 4.1's backend question, and closes §2.3's finding at the point of choice.
Needs the allowlist first, which 021 §5 already proposes.

### 4.4 A local task-quality grader for the corpus (ADR-004 T2+)

Adapter-backed, local, over journal segments; a tier that D4 currently excludes. Sequenced after
ADR-004's T1.

---

## 5. What does not transfer

### 5.1 Nothing in the safety floor

005's ADR-001 puts the floor in core with zero extensions loaded; 028's ADR-001 makes
verification fail closed everywhere. A decision service is an extension-side input that can be
unreachable, slow, or wrong. The empty-stop floor stays a structural check; a guard that cannot
reach its backend returns `NoDecision` and lets the floor and the other guards act; a `Pending`
that times out resolves by its `PolicyDefault`, not by a stale probability.

### 5.2 The two headline claims, read literally

- **"0% hallucination."** The article's own framing is that outputs are "defined in advance," so
  the model cannot go off the rails *of the schema*. That is type safety, which AILANG already
  gives the mapping function for free. It says nothing about whether the chosen arm is right.
- **"Calibrated."** RLCD's target is honest probabilities, and the evals score against the mean
  of two frontier LLMs' probabilities. So "calibrated" means "agrees with what GPT-6 Astra and
  Fable 5.1 would say," which is a proxy for correctness, not correctness. Motoko's decisions
  have outcomes it can observe; §4.1's measurement uses those.

### 5.3 Anything that needs a string

Solver steps, tool arguments, summaries, commit messages, PR replies. The adapter's
`llm_answer_mode="discrete"` and the whole "System One LLM wrapper" exist to get *decisions* out of
LLMs, not to get text out of Jev.

### 5.4 The evaluation methodology as-is

"Workflow evals" assume the compute graph is correct and score the branches. Motoko's ADR-004
already has a stronger notion — strict replay of a recorded program with a verdict that names
what was and was not checked — and should not adopt a reference-LLM oracle where it has ground
truth.

---

## 6. Risks

- **Vendor.** Pre-commercial beta, waitlist, one SDK, pricing possibly subsidised, no retention
  statement. Mitigated by 4.1 being backend-agnostic: the port and the guard survive the vendor.
- **Privacy.** Decision inputs are transcript slices; in the step loop they include the task and
  tool output, and in §3.6 they include journal segments D6 keeps at `0700`. Any remote backend
  is an exposure the corpus's exposure log must record and `dst_secrets.ail`'s scan must clear.
  A local adapter backend has neither problem.
- **Wire format unknown.** AILANG would call the service through `Net`; the article gives no
  endpoint, schema or auth. Until early access supplies them, only the adapter path is real.
- **Threshold drift.** Bands tuned against one backend's calibration will not hold for another.
  The bands must be profile configuration, versioned, and re-measured on backend change — which
  is what 4.1's comparison is.
- **Over-reach.** The type-level fit is seductive; the temptation is to route every `if` in the
  harness through a probability. The rule from 005 holds: mechanism and floor stay deterministic
  and local; only policy at the named seams is a candidate, and only where an outcome can be
  measured.
- **Latency band is a single figure.** 70–500 ms end to end, no distribution, measured from the
  authors' laptops. In the tool path (4.2) the tail matters more than the median.

---

## 7. Candidate follow-ons (none decided)

1. **PLAN: decision port + finalize guard, adapter-backed** (§4.1). Depends on the persist-nudge
   migration landing at `on_solver_candidate` (005) so the guard has one seam to occupy.
   Deliverables: the port and its `RequestClass`; the contracted mapping in the 027 register; a
   DST profile that scripts band-edge answers; an A/B over recorded stops.
2. **Apply for Jev early access** and, when it lands, add the second backend and run the same
   A/B. Record the wire format and retention terms here.
3. **021: `Choice` over the delegate allowlist** (§4.3), after the allowlist exists.
4. **ADR-004 note: a task-quality tier** (§3.6), local backend only, sequenced after T1.
5. **Re-read** when TypeSafe publishes the SDK's wire format or an evals write-up against ground
   truth rather than reference LLMs; §5.2 is the section most likely to need revision.
