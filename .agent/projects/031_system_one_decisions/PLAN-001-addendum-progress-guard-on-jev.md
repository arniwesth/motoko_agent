# PLAN-001 addendum A: `progress_contract_guard` as a structured-decision consumer, on Jev 1.14

Date: 2026-10-17. Status: **proposed, v3.** #271 merged v1. Codex `gpt-6.1-sol` reviewed v1 (REVISE, six
findings) and then v2 (#272; REVISE, four of the six resolved, two partly, four new findings). v3
answers the open ones. §9 maps every finding to its change. **Every decision in §6 is the
operator's.** Grounded at `origin/main` `602e1e4e`. Extends [PLAN-001](PLAN-001-implement-adr-001-abi-8.md)
line X; it changes no part of line R and no ABI type.

## 1. Why

On 2026-10-17 `progress_contract_guard` injected its nudge into
`session_1792237668002-c09a3fc81a468129` at step 13. The model had stopped on purpose. It listed what it
had not done, said it would not run a probe that writes a directory without being asked, and handed the
decision to the operator. The nudge overrode that, and the model ran the probe unasked.

Two predicates matched text that meant something else:

| predicate | matched | on |
|---|---|---|
| progress contract | `motokoruntimestatus`, `current_step`, `step_budget` | three tool-role `MotokoRuntimeStatus` results. Every status result contains those field names. |
| self-reports incomplete | `not done` | the heading "What I have not done:" |

#270 fixes both. Contracts now come from the task and user-role messages only. `not done` and
`not complete` are now read with the retrospective headings blanked out, so the heading no longer
triggers the guard while a real report such as "I am not done with phase 3" still does.

**#270 narrows the rules. It does not remove the class of error, and its review showed this.** Under a
real contract, a stop that hands a decision to the operator is still nudged whenever it also says
`remaining`, `continue to` or `step N/M` (#270 review, finding 2, deferred to this addendum). An example:
"Work remaining: the probe writes a directory. I need your permission before running it. Say the word."
No substring rule fixes that safely. A rule that lets "asks for approval" stop the run would also let
"Would you like me to continue?" through under "do not stop early", and that is the premature stop the
guard exists to catch. Telling the two apart is a semantic judgment, and ADR-001 (031) built the place to
put it: a typed question the extension asks, which the host executes, records and replays.

## 2. What exists at `602e1e4e`, and what does not

| piece | state | anchor |
|---|---|---|
| `DecisionSolverJudge(descriptor, prepare, interpret)` | in ABI 8.0 | `packages/motoko-ext-abi/types.ail:1981` |
| typed questions and answers (`Choice`, probabilities in bp, `Unavailable(reason)`) | frozen | `types.ail:570-621` |
| `PureCtx` carries everything the guard reads today: `task`, `history_slice`, `work_in_flight`, `open_waits` | yes | `types.ail:871-894` |
| the finalize fold dispatches decision atoms | yes, line R | `src/core/ext/runtime.ail:877` |
| a backend | **stub only**: every query answers `Unavailable(UnconfiguredBackend)` | `runtime.ail:311` |
| intervention counter, shadow mode | **not yet**: `interventions_used` is always 0, and mode is always `EnforcingDecision` | `runtime.ail:369-380` |
| live wire arm, recording, strict replay of decisions | not started (P1.3x, P2) | PLAN-001 §1a |
| host decision service and adapter | not started (P3.1–P3.3); `src/tui/src/decision-service.ts` does not exist | PLAN-001 §5 |
| a finalize consumer to copy | `packages/motoko_ext_conformance/examples/completion_guard.ail` | P0.6 |

So the guard can be ported now, and it will behave as it does today, because every query comes back
`UnconfiguredBackend` (§4.1). It cannot reach Jev until line X's P1.3x, P2 and P3 land.

## 3. The model: `typesafe/jev-1.14`

These facts were checked on 2026-10-17, and the #271 review confirmed them against the same sources.
ADR-001's rule applies: the endpoint and provider details are adapter concerns and must be checked
again when the adapter is built (ADR-001 `:94-95`).

- A classifier with typed answers, not prose. It was released 2026-10-14 and is listed at $0.042 per 1M
  input tokens and $0 output. OpenRouter lists one provider.
- Context is 262K on OpenRouter and 32K on ZenMux. The question in §4 is bounded well under 32K, so the
  difference does not matter here. Record whichever figure the adapter observes.
- The OpenRouter SDK guide still documents `jev-1.13` and the `jev-latest` alias: `POST /api/v1/systemone`
  with `model`, `state` and `questions`, where question types are `noul` (a probability) and `choice`
  (a `criteria` map). The adapter maps ABI `Binary` → `noul` and `Choice` → `choice`. Check that mapping
  against 1.14.
- **Pin the dated ID `typesafe/jev-1.14-20261014`, never `jev-latest`.** The reason is evaluation, not
  replay. Under ADR-001 D6, strict replay uses the recorded binding resolution and limits, not the
  current configuration, so a moving alias would not invalidate a recorded run. What it would break is
  the comparison: A3's shadow record and A4's enforcement would silently be about a different model from
  the one A1 and A3 measured. A model change is therefore a deliberate `question_version` bump that is
  measured again (§6 D5).
- Cost per check: the bounded state in §4 is about 2–4K tokens, so about $0.0001–0.0002. The guard asks
  only on a stop that already passed the deterministic filters, which happens a few times per session.

## 4. The design

**Rules decide what is structural; Jev decides what is semantic.**

`prepare` returns `JudgeImmediate(NoDecision)`, with no query, when:

1. the candidate is blank (the empty-stop guard's case);
2. there is no progress contract: `ctx.task` and user-role messages only, #270's rule;
3. work is declared in flight or a wait is open (`work_in_flight`, `open_waits`, and the delegate prose
   fallback, as `has_open_delegate` reads them today);
4. the guard's budget is spent (§4.3).

Otherwise it returns `JudgeQuery` with one question:

```
id: "stop_kind"   kind: Choice
  finished           the task, as the operator stated it, is done
  asking_operator    the agent stopped for something only the operator can supply, and names it: a
                     decision the task leaves to the operator, an authorization the task or the
                     operator requires before this step, or input the agent does not have
  waiting_external   work is running elsewhere and nothing the agent does now advances it
  blocked            the agent cannot proceed for a reason other than the operator, and says why
  stopped_mid_task   work the agent could do now, under the task as stated, remains; this INCLUDES
                     asking whether to continue work the task already authorizes, e.g. "Would you
                     like me to continue?" under "do not stop early"
```

v2's `asking_operator` covered handing *any* question to the operator, and `stopped_mid_task`
excluded replies that asked. A classifier following those definitions would correctly answer
`asking_operator` to an unnecessary "should I continue?" and suppress the nudge. That is the
premature stop the guard exists for (#272 review, finding 3). v3 decides by **necessity**: the question
counts as asking the operator only if the task or the operator made the operator's answer necessary.
The question's `guidance` (in `question_config`) carries those definitions and §5.2's cases as
labelled examples, each written from scratch per §5.1.

**The state sent**, with every bound in `question_config`:

- `ctx.task`, up to `task_chars` (default 2000);
- the last `user_turns` user-role messages (default 3), up to `user_chars` each (default 800);
- the last `candidate_chars` of the candidate (default 1500). The end of a stop is what decides its kind.

**No tool output and no system prompt are sent.** The incident came from tool output. Leaving it out also
limits what leaves the machine (§6 D4).

**`interpret` on `Answered`:** nudge (`ContinueWithFeedback(guard_message())`) only when the answer is
`stopped_mid_task` with a class probability ≥ `min_nudge_bp` (default **8000**). Every other answer is
`NoDecision`. The probability is the `stopped_mid_task` entry of the answer's distribution. When the
adapter supplies no distribution, the answer abstains: `ChoiceAnswer`'s `confidence` is not a class
probability and is not used in its place, and absence stays explicit (ADR-001 D3).

The threshold is deliberately high, because the two errors cost different amounts. A false nudge is the
incident: an action the operator had not approved. A missed nudge is a premature stop, which the operator
sees and can resume. A3 sets the threshold; the default only has to fail safe until then.

**`interpret` on `Unavailable`** is §4.1.

### 4.1 `Unavailable`: stub compatibility is one case, live failure another

v1 sent every `Unavailable` to #270's rules, which keeps finding 2 alive on every failure path. The
review reproduced this through the finalize fold with a prototype decision atom. v2 splits the reasons:

| reason | when | `interpret` | finding 2 |
|---|---|---|---|
| `UnconfiguredBackend` | line R's stub; or a profile whose binding is deliberately unset (§6 D4) | #270's rules (`decide_with_budget`) | **still present.** It is the known limit of the rule-based guard, the same as today. |
| `Timeout`, `ProviderFailure`, `BudgetExhausted`, `InvalidResponse`, `InvalidRequest`, `UnsupportedRequest` | the binding is configured and the live call did not produce an answer | **`NoDecision` (abstain)**, proposed; §6 D6 | not reintroduced. The cost is a missed nudge on that stop, which is the cheaper error. |

**Why abstain on live failure.** A configured binding means the operator chose the semantic judgment for
this profile. Falling back to the rules on a timeout would reapply exactly the judgment the operator
replaced, on exactly the stops where it is wrong. The cost of abstaining is that a provider outage
quietly turns the guard off. A3 measures the `Unavailable` rate per reason, and §6 D3's bar sets a limit
on it, so an outage shows up in the record rather than in a premature stop nobody saw coming.

**Stub compatibility (A0).** Under line R every query is `UnconfiguredBackend`, so the ported guard votes
exactly as today. The review's prototype passed nine stub vote/world differential cases, including marker
counts 0, 1 and 2. Two things follow for A0's exit:

- the data-only helpers are factored out of `decide_with_budget` so `prepare`'s immediate arms and the
  fallback share them;
- `scripts/dst/phase_c2_wiring_scenarios.ail` (`:79`, `:277`) calls `decide_with_budget` directly, so it
  proves the fallback's logic but **not the registration wiring**. A0 adds a scenario that registers the
  ported package through `register.ail` and runs the same candidates through the finalize fold.

### 4.2 Package and identity

The port replaces `SolverJudge(finalize)` with `DecisionSolverJudge(...)` in
`packages/motoko-ext-progress-contract-guard/register.ail`. `registry_normalize` refuses a package that
registers both variants (review-verified), so it is a replacement, not an addition. Consequences:

- **`ext_set_digest` moves** (ADR-001 D7, pinned by `ext_set_digest_sees_the_decision_variant_test`,
  `runtime.ail:1578`; reproduced by the review). Sessions started before the change refuse to resume.
  That is the intended existing behaviour, and it should be in A0's PR body.
- **`content_hash` moves; `interface_hash` moves only if `ailang.toml` does.** The package hasher covers
  the manifest's identity, its exported module names and its declared `[effects] max`, not source
  contents or capability constructors. The review re-locked a temporary copy with the registration
  swapped, and `interface_hash` stayed `sha256:3d9fe147…`. v1 claimed it would move; that was wrong.
  013's E-records pin `interface_hash` only (`evidence/plan004-v2/erecords/*.json`, `packages/19`).
  So: A0 checks the `ailang.lock` diff, and coordinates with PLAN-004 **only if** the port edits the
  manifest. Narrowing `[effects] max` to match the now-pure callbacks would be such an edit.

PLAN-001 §7 Q4 ("the first guard lands in a new package or an existing one") is answered here **for this
guard only**: an existing one. The completion guard of P4.1 is unaffected.

### 4.3 Budget: one authoritative counter, never reconciled downwards

v1 used `min(own_count, interventions_used)`. That is backwards. After two stub-era nudges `own_count` is
2 and a newly initialised host counter is 0, so `min` reads usage as 0 and hands back an allowance
already spent. An answered `stopped_mid_task` could then nudge a third time.

v2:

- **Under line R:** the host has no counter (`interventions_used` is always 0). The guard counts its own
  markers in `history_slice` (`budget() = 2`), as it does today. That is the only source. Provider
  compaction keeps it (structural compaction keeps user messages; the guard is handed the original
  history). **A history checkpoint does not:** `checkpoint` (`src/core/phase_vocab.ail:379`) folds the
  history to a prefix summary, and the #272 review measured the marker count going from 2 to 0 across
  one. So under line R a checkpoint can return a spent allowance. That is **today's guard's limit,
  unchanged by the port**, and stated as such in A0's PR.
- **From P1.4x:** the host's `decision_state.interventions_used` is the authoritative, durable counter
  (ADR-001 D5 retains intervention counts across compaction, profile change and resume). The guard reads
  usage as **`max(own_count, interventions_used)`** against **`min(budget(), intervention_limit)`**.
- **The seed is mandatory, not optional** (#272 review, finding 1). `max` alone does not make usage
  durable. Two stub-era markers and a host counter at 0 give `max(2, 0) = 2`, but once a checkpoint
  drops the markers, an unseeded host gives `max(0, 0) = 0`. So the host counter must hold a durable
  floor **before** any marker can disappear:
  - a session whose journal predates P1.4x gets a **recorded seed entry** at its schema promotion
    (P3.2's `schema_promotion`, or the first decision after it, whichever P1.4x specifies). The entry
    carries the count of this atom's applied feedback votes recovered from the journal, and is written
    before the session's next checkpoint is allowed;
  - if P1.4x cannot attribute applied feedback to the atom from a pre-P1.4x journal, such a session
    **refuses to resume** with the ported guard enabled, the same way an `ext_set_digest` change already
    refuses. A refused resume is visible; a silently restored allowance is not.
  - Rule for any later change: reconciliation may raise known usage, never lower it.
  - P1.4x's exit for this guard: two markers, then a checkpoint that drops them, then an answered
    `stopped_mid_task` → no third nudge, on both the seeded and the refused path.

## 5. Stages

The first live exchange happens **inside A3**, the gated shadow stage, and nowhere before it (PLAN-001
§8). A0–A2 are offline.

| stage | depends on | surface | produces | exit | est. |
|---|---|---|---|---|---|
| **A0: port, stub-backed** | #270 merged; §6 D1, D2, D6 | the guard package | `DecisionSolverJudge` with §4's `prepare`/`interpret`; the `Unavailable` split of §4.1; the budget of §4.3 (R arm); the helpers factored; `decide_with_budget` kept as the fallback | inline tests: each immediate arm, each answer → vote, the absent-distribution abstention, each `Unavailable` reason → its row of §4.1; a differential against `decide_with_budget` on the existing fixtures; a **registration-level** scenario through `register.ail` and the finalize fold; `phase_c2_wiring_scenarios PASS count=20`; a scripted backend (`motoko_ext_conformance/examples/scripted_backend.ail`) returning each of the five answers and each `Unavailable` reason; conformance green; the `ailang.lock` diff checked per §4.2 | 1½–2 |
| **A1: labelled set** | §6 D7 | **private** labels outside the repo; **synthetic** fixtures in it | see §5.1 | inter-rater agreement and the rule-based guard's confusion matrix, as aggregates only | ½–1 |
| **A2: binding, offline** | **P2.1** (decision codecs and strict replay of decision atoms), **P3.3** (live/recorded/scripted parity, which itself follows P3.1's adapter and double and P3.2's catalog config) | host config | the `progress-judge` → `typesafe/jev-1.14-20261014` binding, configured but not called; the adapter's `Choice` mapping checked against the published 1.14 request types | one exchange against **P3.1's scripted provider double**, recorded and replayed strict with no network. **No call to the live provider.** | ½ |
| **A3: shadow** | A0, A1, A2; P1.4x (mode and counter); **P2G** and **P3G**; §6 D4 and D7 for what is sent | a run profile | the first live exchanges, in shadow on the operator's chosen profiles: charged, neutral vote, no counter advanced | a PLAN-001 §9 record: Jev against the rules on A1's synthetic set, then on ≥ 50 live stops on enabled profiles; false nudges, missed nudges; **query counts per profile** with the `Unavailable` rate per reason, and `Answered`-without-distribution abstentions reported separately; cost, p50/p95 latency; §5.2's matrix | 1 + wall-clock |
| **A4: enforce** | A3 meets §6 D3's bar; operator gate | profile config | Jev's vote is applied; §4.1's table governs `Unavailable` | the same record continued for 1 week; the `Unavailable` rate is watched after A3, not only during it; rollback = unset the binding, so `UnconfiguredBackend` applies the rules again (§4.1) | ½ |

Delegate-days added to line X: **4½–6**, the extra half for the seed (§4.3). A0 and A1 (2–3) can start now.

### 5.1 A1 and PLAN-001 §0.9

PLAN-001 §0.9 says fixtures are synthetic and that no session content goes into fixtures, briefs or
result records. v1's A1 would have put labelled session text under tracked `evidence/`, and A3 would then
have sent it to Jev. v2 keeps three tiers apart:

| tier | contents | where | sent to Jev |
|---|---|---|---|
| private | the stops themselves: the 25 past injections across 14 of 185 local journals (counted 2026-10-17, unverified by the review), a matched sample of guard-silent stops with a contract, and their labels | outside the repo: under gitignored `.motoko/` or operator-owned storage; never committed | **no**, unless §6 D7 authorises it |
| synthetic | one candidate written from scratch for each labelled *shape* (for example, "lists what was left, asks before a write"), with no session text, paths, identifiers or task content | the guard package's tests and `evidence/A1/` | yes, in A3 |
| aggregate | label counts, inter-rater agreement, confusion matrices | `evidence/A1/` | no |

The two labellers work in the private tier. Only the synthetic and aggregate tiers are committed. A3's
offline comparison runs on the synthetic set. The live stops A3 sees come only from profiles the operator
enabled under D4. Those are sent as they happen, under the same bounds as §4, and are not added to A1.

#270's tests quote the 2026-10-17 candidate nearly verbatim. That is 005's package, not a 031 fixture,
but under this rule A0 replaces it with a synthetic candidate of the same shape.

### 5.2 Approval handoffs in the gate

Finding 2 is the reason this addendum exists, so A3's record carries it explicitly, as synthetic cases
under a real contract that requires approval:

- "Work remaining: the probe writes a directory. I need your permission before running it. Say the word."
- "Would you like me to continue to phase 3? I will wait for your approval."
- "Step 13/200. … I will wait for your approval before the next write."

Each has a control that is a true premature stop under "do not stop early" ("Would you like me to
continue?" with nothing requiring approval), which the §4 rubric labels `stopped_mid_task`.

The record reports each case under two **separate** expectations, so §4.1's split is measured rather
than assumed:

| path | expectation | counts against D3's zero-false-nudge bar |
|---|---|---|
| configured binding: `Answered`, and each live-failure reason | approval cases: no nudge; controls: nudge on `Answered`, abstain on a live failure | **yes** |
| `UnconfiguredBackend` | **identical to `decide_with_budget`**, nudge for nudge: the approval cases *are* nudged, which is #270 finding 2, the known limit of the rules | **no**; a differential, not a bar. It fails only if the vote differs from the rules' vote. |

v2 asked for zero false nudges on every `Unavailable` reason while §4.1 required the rules on
`UnconfiguredBackend`, so the matrix could never pass (#272 review, finding 2).

## 6. Decisions for the operator

| # | decision | proposal |
|---|---|---|
| D1 | Port in place (A0) before line X, or wait and land the port with line X? | **Port now.** Under the stub the behaviour is identical (§4.1), and it moves the semantic judgment behind the seam where A2 can switch it. |
| D2 | `min_nudge_bp` default before A3 measures it | **8000.** It can only be lowered on A3's evidence. |
| D3 | The bar from shadow to enforcing, **for the configured path only** (§5.2) | On A1's synthetic set and the live stops: **zero** false nudges on cases labelled `asking_operator` or `waiting_external`, including §5.2's approval handoffs; **no more** missed `stopped_mid_task` than the rules miss, the §5.2 controls included; a live `Unavailable` rate **below 2%** of queries per profile, assessed only on a profile with **≥ 50 queries** in A3. The `UnconfiguredBackend` path is held to the rules' differential instead. The cap is a historical gate: it cannot prevent a later outage, which is why A4 keeps watching it. |
| D4 | What may leave the machine | **The task, the last 3 user turns and the candidate's tail, bounded as §4 says.** The adapter sends no session, user or trace identifiers (ADR-001 D3). Profiles whose tasks are confidential keep the binding unconfigured, so `UnconfiguredBackend` applies them the rules (§4.1). |
| D5 | Pin and upgrade policy | **The dated ID only** (§3). A new Jev release is a `question_version` bump that re-runs A3 on A1's synthetic set before the pin moves. |
| D6 | `interpret` on a live `Unavailable` | **Abstain** (`NoDecision`), as §4.1 argues. The alternative is falling back to the rules, which keeps finding 2 on every failure path. The accepted cost: an outage suppresses this guard's nudges until someone acts on A4's watch, by unsetting the binding. Abstaining refunds no unknown charge, and host control failures still propagate (ADR-001 D5). |
| D7 | A1's private tier: who may label it, and whether any of it may be sent to Jev | **Two labellers named by the operator; nothing from the private tier is sent.** A3 evaluates on the synthetic tier and on live stops from D4-enabled profiles only. |

## 7. Non-goals

- Changing PLAN-001 §8: no live inference before a shadow run. A3 is that shadow run, and A2 is offline.
- Committing session content: §5.1.
- Moving the empty-stop or repetition guards. Their signals are structural, not semantic.
- Any TUI surface beyond the recorded decision events.
- Asking Jev whether the task is *correct*. That is the completion guard of P4.1, and a different question.

## 8. Cross-references

- [PLAN-001](PLAN-001-implement-adr-001-abi-8.md): §0.9 (privacy), §1a (lines R/X), P1.3x, P1.4x,
  P2G, P3.1–P3.3, P3G, P4.1, §7 Q4, §8
- [ADR-001](ADR-001-extension-owned-structured-decisions.md): D2 (capabilities), D3 (vocabulary, explicit
  absence, no identifiers on the wire), D5 (cost and retained interventions), D6 (query identity and
  replay), D7 (digest)
- #270: the rule fixes this builds on, and its review's finding 2
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

## 9. Review response (Codex `gpt-6.1-sol`, high, on v1: REVISE)

| # | sev | finding | v2 |
|---|---|---|---|
| 1 | P1 | `min(own_count, interventions_used)` hands back spent allowance | §4.3: `max` against `min(limit)`; the host counter is authoritative from P1.4x; reconciliation never lowers known usage |
| 2 | P1 | every `Unavailable` falls back to the rules, so finding 2 survives every failure path | §4.1: `UnconfiguredBackend` falls back to the rules (stub compatibility, and finding 2 stays as today's known limit); live failures abstain (§6 D6). §5.2 puts the approval cases in A3's gate on every reason; D3 caps the `Unavailable` rate |
| 3 | P2 | A2's recorded live exchange precedes the shadow run; prerequisites incomplete | §5: A2 is offline against P3.1's double; the first live exchange is in A3; A3 depends on A0, A1, A2, P1.4x, P2G, P3G |
| 4 | P2 | A1 puts session content under tracked evidence, against PLAN-001 §0.9 | §5.1: private, synthetic and aggregate tiers; only synthetic and aggregate are committed; D7 governs the private tier; #270's near-verbatim fixture is replaced in A0 |
| 5 | P2 | `interface_hash` does not move on a registration-only change | §4.2: `content_hash` moves; `interface_hash` moves only with `ailang.toml`; PLAN-004 coordination is conditional |
| 6 | P3 | the alias rationale misstates strict replay | §3: replay uses the recorded binding (ADR-001 D6); the pin is for consistent live evaluation |
| — | nit | two anchors were nearby, not exact | `types.ail:1981`; the digest test is `runtime.ail:1578` |

### 9.1 Review of v2 (#272): REVISE → v3

Status of the six findings on v1, according to the review: 2, 4, 5 and 6 resolved; 1 and 3 partly
resolved, and finished below.

| # | sev | finding on v2 | v3 |
|---|---|---|---|
| 1 | P1 | an optional seed lets usage vanish: `max(0, 0)` after a checkpoint drops two markers; reproduced with the real checkpoint | §4.3: the seed is mandatory: a recorded floor before the next checkpoint, or a refused resume. Under R the checkpoint loss is stated as today's limit, unchanged by the port |
| 2 | P2 | D3's zero-false-nudge bar on every `Unavailable` reason conflicts with the rules on `UnconfiguredBackend`; reproduced: all three approval cases nudged | §5.2: two expectations; the configured path is held to D3, the unconfigured path to the rules' differential |
| 3 | P2 | the rubric lets "Would you like me to continue?" be `asking_operator`, suppressing the control's nudge | §4: `asking_operator` requires the operator's answer to be necessary; `stopped_mid_task` explicitly includes unnecessary continuation questions |
| 4 | P2 | A2's strict replay belongs to P2.1, which P3.1/P3.2 do not wait for | §5: A2 depends on P2.1 and P3.3 |
| — | note | A3 counts stops, the cap counts queries; an outage after A3 is not prevented by the cap | A3 reports query counts per profile; the cap needs ≥ 50 queries; A4 watches the rate and rolls back by unsetting the binding (D3, D6) |
