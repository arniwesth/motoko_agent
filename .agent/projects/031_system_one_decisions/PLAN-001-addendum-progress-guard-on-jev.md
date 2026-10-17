# PLAN-001 addendum A: `progress_contract_guard` as a structured-decision consumer, on Jev 1.14

Date: 2026-10-17. Status: **proposed — every decision in §6 is the operator's.** Grounded at `origin/main`
`602e1e4e`. Extends [PLAN-001](PLAN-001-implement-adr-001-abi-8.md) line X; it changes no part of line R
and no ABI type.

## 1. Why

On 2026-10-17 `progress_contract_guard` injected its nudge into
`session_1792237668002-c09a3fc81a468129` at step 13. The model had stopped on purpose. It listed what it
had not done, said "it does write a probe directory, so I won't fire it unasked. Say the word and I'll run
it", and handed the decision to the operator. The nudge overrode that, and the model ran the probe unasked:
`/tmp/p22probe`, then `.motoko/eval-tmp/p22probe-*`.

Two predicates matched text that meant something else:

| predicate | matched | on |
|---|---|---|
| progress contract | `motokoruntimestatus`, `current_step`, `step_budget` | three tool-role `MotokoRuntimeStatus` results (journal lines 11, 24, 44). Every status result contains those field names. |
| self-reports incomplete | `not done` | the heading "What I have not done:" |

Branch `fix/progress-guard-contract-source` (commit `9720568a`) fixes both. Contracts now come from the
task and user-role messages only, and `not done` / `not complete` match only where they describe the task.
Four inline tests pin the fixes, and four mutants are all killed.

**That fix narrows the rules. It does not remove the class of error.** The guard still decides with
substring rules whether a response is "finished", "asking the operator", "waiting on something else" or
"stopped mid-task". `remaining`, `continue to` and `step …/…` can each misfire the same way: a response
saying "the remaining question is yours" asks the operator, but it matches `remaining`. That judgment is
semantic. ADR-001 (031) built the place to put it: a typed question the extension asks, which the host
executes, records and replays.

## 2. What exists at `602e1e4e`, and what does not

| piece | state | anchor |
|---|---|---|
| `DecisionSolverJudge(descriptor, prepare, interpret)` | in ABI 8.0 | `packages/motoko-ext-abi/types.ail:1983` |
| typed questions and answers (`Choice`, probabilities in bp, `Unavailable(reason)`) | frozen | `types.ail:570-621` |
| `PureCtx` carries everything the guard reads today: `task`, `history_slice`, `work_in_flight`, `open_waits` | yes | `types.ail:871-894` |
| the finalize fold dispatches decision atoms | yes, line R | `src/core/ext/runtime.ail:877` |
| a backend | **stub only**: every query answers `Unavailable(UnconfiguredBackend)` | `runtime.ail:311` |
| intervention counter, shadow mode | **not yet**: `interventions_used` is always 0, and mode is always `EnforcingDecision` | `runtime.ail:369-380` |
| live wire arm, recording, strict replay of decisions | not started (P1.3x, P2) | PLAN-001 §1a |
| host decision service and adapter | not started (P3.1–P3.3); `src/tui/src/decision-service.ts` does not exist | PLAN-001 §5 |
| a finalize consumer to copy | `packages/motoko_ext_conformance/examples/completion_guard.ail` | P0.6 |

So the guard can be ported now, and it will behave as it does today, because every query comes back
`Unavailable`. It cannot reach Jev until line X's P1.3x, P2 and P3 land.

## 3. The model: `typesafe/jev-1.14`

These facts were checked on 2026-10-17. ADR-001's rule applies: the endpoint and provider details are
adapter concerns and must be checked again when the adapter is built (ADR-001 `:94-95`).

- A classifier with typed answers, not prose. It was released 2026-10-14 and is listed at $0.042 per 1M
  input tokens and $0 output. OpenRouter lists one provider.
- Context is 262K on OpenRouter and 32K on ZenMux. The question in §4 is bounded well under 32K, so the
  difference does not matter here. Record whichever figure the adapter observes.
- The OpenRouter SDK guide still documents `jev-1.13` and the `jev-latest` alias: `POST /api/v1/systemone`
  with `model`, `state` and `questions`, where question types are `noul` (a probability) and `choice`
  (a `criteria` map). The adapter maps ABI `Binary` → `noul` and `Choice` → `choice`. Check that mapping
  against 1.14.
- **Pin the dated ID `typesafe/jev-1.14-20261014`, never `jev-latest`.** D6 puts the resolved backend
  model in the query identity, so a moving alias would break strict-replay matching the day it moves.
- Cost per check: the bounded state in §4 is about 2–4K tokens, so about $0.0001–0.0002. The guard asks
  only on a stop that already passed the deterministic filters, which happens a few times per session.

## 4. The design

**Rules decide what is structural; Jev decides what is semantic.**

`prepare` returns `JudgeImmediate(NoDecision)`, with no query, when:

1. the candidate is blank (the empty-stop guard's case);
2. there is no progress contract: `ctx.task` and user-role messages only, the rule `9720568a` set;
3. work is declared in flight or a wait is open (`work_in_flight`, `open_waits`, and the delegate prose
   fallback, as `has_open_delegate` reads them today);
4. the guard's budget is spent (§4.3).

Otherwise it returns `JudgeQuery` with one question:

```
id: "stop_kind"   kind: Choice
  finished           the task, as the operator stated it, is done
  asking_operator    the response ends by handing a decision, approval or question to the operator
  waiting_external   work is running elsewhere and nothing the agent does now advances it
  blocked            the agent cannot proceed and says why
  stopped_mid_task   work the agent could do now remains, and it neither finished nor asked
```

**The state sent**, with every bound in `question_config`:

- `ctx.task`, up to `task_chars` (default 2000);
- the last `user_turns` user-role messages (default 3), up to `user_chars` each (default 800);
- the last `candidate_chars` of the candidate (default 1500). The end of a stop is what decides its kind.

**No tool output and no system prompt are sent.** The incident came from tool output. Leaving it out also
limits what leaves the machine (§6 D4).

**`interpret`:**

- `Answered`, and `stopped_mid_task` has probability ≥ `min_nudge_bp` (default **8000**) →
  `ContinueWithFeedback(guard_message())`;
- `Answered`, any other answer → `NoDecision`;
- `Unavailable(_)` → today's rule-based decision: `decide_with_budget` with the `9720568a` predicates.

The threshold is deliberately high, because the two errors cost different amounts. A false nudge is the
incident: an action the operator had not approved. A missed nudge is a premature stop, which the operator
sees and can resume. P4.3's measurements set the threshold. The default only has to fail safe until then.

### 4.1 Fallback under line R

Under the stub every query is `Unavailable(UnconfiguredBackend)`, so a ported guard behaves exactly like
today's guard. That is what makes stage A0 safe to land before line X. The DST scenarios in
`scripts/dst/phase_c2_wiring_scenarios.ail` (`:79`, `:277`) call `decide_with_budget` directly. Keep that
function exported, and those twenty scenarios stand unchanged as the test of the fallback.

### 4.2 Package and identity

The port replaces `SolverJudge(finalize)` with `DecisionSolverJudge(...)` in
`packages/motoko-ext-progress-contract-guard/register.ail`. Two consequences follow:

- `ext_set_digest` moves (ADR-001 D7, pinned by `runtime.ail:1567`), so sessions started before the
  change refuse to resume. That is the existing behaviour on purpose, and it should be in the PR body.
- The package's `interface_hash` moves. 013's E-records pin it
  (`evidence/plan004-v2/erecords/*.json`, `packages/19`). Coordinate with PLAN-004 before A0 merges, so
  that an evaluation in flight does not find its identities changed. `9720568a` changed only
  `content_hash`, so the fix does not raise this issue.

PLAN-001 §7 Q4 ("the first guard lands in a new package or an existing one") is answered here **for this
guard only**: an existing one. The completion guard of P4.1 is unaffected.

### 4.3 Budget

Under R the host's counter is always 0 (`runtime.ail:369-380`). Until P1.4x, the guard keeps counting its
own markers in `history_slice`, as it does today (`budget() = 2`). After P1.4x it uses
`min(own_count, decision_state.interventions_used)` against `min(budget(), intervention_limit)`. Then
neither source alone can reset the allowance: compaction can drop markers from the history, and resume
can lose a counter.

## 5. Stages

| stage | depends on | surface | produces | exit | est. |
|---|---|---|---|---|---|
| **A0 — port, stub-backed** | `9720568a` merged; §6 D1, D2 | the guard package | `DecisionSolverJudge` with §4's `prepare`/`interpret`; `decide_with_budget` kept as the fallback | inline tests: each immediate arm, each answer → vote, `Unavailable` → the rules (differential against `decide_with_budget` on the existing fixtures); `phase_c2_wiring_scenarios PASS count=20`; a scripted backend from `motoko_ext_conformance/examples/scripted_backend.ail` returning each of the five answers; conformance green | 1–1½ |
| **A1 — labelled set** | none (runs in parallel with A0) | record only, `.agent/projects/031_…/evidence/A1/` | the 25 past injections across 14 of 185 local journals (counted 2026-10-17) plus a matched sample of guard-silent stops with a contract, each labelled with one of §4's five options by a reviewer other than the labeller; the 2026-10-17 candidate is case 1 | inter-rater agreement recorded; the rule-based guard's confusion matrix on the set | ½–1 |
| **A2 — the binding** | P3.1 (the adapter), P2.1 (codecs) | host config | the `progress-judge` → `typesafe/jev-1.14-20261014` binding; the adapter's mapping of `Choice` re-verified against 1.14 | one recorded live exchange replayed strict with no network (P3.3's parity, one more atom) | ½ |
| **A3 — shadow** | P1.4x (mode and counter), A1, A2 | a run profile | shadow on the operator's chosen profiles: charged, neutral vote | §9 record: Jev vs rules vs labels on A1, then on ≥ 50 live stops; false nudges, missed nudges, cost, p50/p95 latency, `Unavailable` rate | 1 + wall-clock |
| **A4 — enforce** | A3 meets §6 D3's bar; operator gate | profile config | Jev's vote is applied; the rules stay as the `Unavailable` fallback | the same record continued for 1 week; rollback = profile back to shadow | ½ |

Delegate-days added to line X: **3½–5**, of which A0 and A1 (2–2½) can start now.

## 6. Decisions for the operator

| # | decision | proposal |
|---|---|---|
| D1 | Port in place (A0) before line X, or wait and land the port with line X? | **Port now.** Under the stub the behaviour is identical, and it moves the semantic judgment behind the seam where A2 can switch it. |
| D2 | `min_nudge_bp` default before A3 measures it | **8000.** It can only be lowered on A3's evidence. |
| D3 | The bar from shadow to enforcing | **On A1 and the live stops: zero false nudges on cases labelled `asking_operator` or `waiting_external`, and no more missed `stopped_mid_task` than the rules miss.** |
| D4 | What may leave the machine | **The task, the last 3 user turns and the candidate's tail, bounded as §4 says.** The adapter sends no session, user or trace identifiers (ADR-001 D3). Profiles whose tasks are confidential keep the binding unconfigured, which means the rules apply. |
| D5 | Pin and upgrade policy | **The dated ID only.** A new Jev release is a `question_version` bump that re-runs A3 on A1 before the pin moves. |

## 7. Non-goals

- Changing PLAN-001 §8: no live inference before a shadow run, and A3 is that shadow run.
- Moving the empty-stop or repetition guards. Their signals are structural, not semantic.
- Any TUI surface beyond the recorded decision events.
- Asking Jev whether the task is *correct*. That is the completion guard of P4.1, and a different question.

## Cross-references

- [PLAN-001](PLAN-001-implement-adr-001-abi-8.md): §1a (lines R/X), P1.3x, P1.4x, P3.1–P3.3, P4.1, §7 Q4,
  §8
- [ADR-001](ADR-001-extension-owned-structured-decisions.md): D2 (capabilities), D3 (vocabulary, no
  identifiers on the wire), D5 (cost and interventions), D6 (query identity and replay), D7 (digest)
- `.agent/issues/progress-guard-prose-heuristics-permit-premature-stop.md`: the same module's earlier
  misfires, in the other direction
- [005 PLAN-progress-contract-guard](../005_harness_policy_boundary/PLAN-progress-contract-guard.md): the
  guard's origin
- 013 [PLAN-004](../013_core_architecture_for_dst/PLAN-004-implement-adr-004.md): E-record identities
  (§4.2)
- Jev 1.14: <https://openrouter.ai/typesafe/jev-1.14>, the dated ID
  <https://openrouter.ai/typesafe/jev-1.14-20261014>, the SDK guide
  <https://openrouter.ai/docs/guides/community/typesafe-sdk>, ZenMux's listing
  <https://zenmux.ai/typesafe/jev-1.14>
