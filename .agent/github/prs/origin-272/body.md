---
repo: arniwesth/motoko_agent
pr: 272
branch: docs/031-addendum-a-v2
ticket: null
title: "docs(031): addendum A v2 — the six findings of the #271 review"
---

## Summary

#271 merged v1 of PLAN-001 addendum A, which proposes moving `progress_contract_guard`'s "what kind of stop is this?" judgment to a structured decision answered by `typesafe/jev-1.14-20261014`. Codex `gpt-6.1-sol` (high) reviewed v1 while it was open and returned **REVISE** with six findings. This is v2, and it takes all six. Two are design errors in v1: the budget rule handed back spent allowance, and every `Unavailable` fell back to the rules, so #270's finding 2 came back on every failure path. The other four tighten staging, privacy, an identity claim and a rationale.

Documents only. No code, no ABI change, and no change to line R.

## Changes

- docs(031): addendum A v2 — the six findings of the #271 review
- docs(031): addendum A v3 — the four findings of the #272 review
- docs(031): addendum A v4 — the two findings of the v3 review
- docs(031): addendum A v5 — the three findings of the v4 review
- docs(031): addendum A v6 — operator-turn provenance becomes prerequisite P-OT

1 file changed: `.agent/projects/031_system_one_decisions/PLAN-001-addendum-progress-guard-on-jev.md`. #271's merged PR record is left as it was.

| # | sev | finding on v1 | v2 |
|---|---|---|---|
| 1 | P1 | the budget's `min(own_count, interventions_used)` hands back spent allowance (two stub-era nudges, then a host counter starting at 0, read as 0 used) | §4.3: `max(own, host)` against `min(budget, limit)`; the host counter is authoritative from P1.4x; reconciliation never lowers known usage |
| 2 | P1 | every `Unavailable` falls back to #270's rules, so approval handoffs are nudged again on every failure path; reproduced through the finalize fold | §4.1: `UnconfiguredBackend` → rules (stub compatibility; finding 2 stays as today's known limit); live failures → abstain (decision D6); §5.2 puts the approval handoffs in A3's gate for `Answered` and every `Unavailable` reason; D3 caps the `Unavailable` rate |
| 3 | P2 | A2's recorded live exchange came before the shadow run, against PLAN-001 §8; prerequisites incomplete | §5: A2 is offline against P3.1's scripted provider double; the first live call is in A3; A3 depends on A0–A2, P1.4x, P2G and P3G |
| 4 | P2 | A1 put session content under tracked evidence, against PLAN-001 §0.9 | §5.1: private, synthetic and aggregate tiers; only synthetic and aggregate are committed; decision D7; #270's near-verbatim fixture is replaced in A0 |
| 5 | P2 | `interface_hash` does not move on a registration-only change; reproduced by re-locking a copy | §4.2: `content_hash` moves; `interface_hash` moves only if `ailang.toml` does; PLAN-004 coordination is conditional |
| 6 | P3 | the pin's rationale misstated strict replay | §3: replay uses the recorded binding (ADR-001 D6); the pin keeps live evaluations about one known model |

The review's two near-miss anchors are corrected (`types.ail:1981`, `runtime.ail:1578`). A0 also gains a registration-level scenario, because the existing DST scenarios call `decide_with_budget` directly and do not exercise `register.ail`. The review raised that point among its verification notes.

### Review of v2 (this PR): REVISE → v3

According to the review, v1's findings 2, 4, 5 and 6 were resolved and 1 and 3 partly. v3 finishes them and takes the four new findings:

| # | sev | finding on v2 | v3 |
|---|---|---|---|
| 1 | P1 | an optional seed lets usage vanish: a checkpoint drops two markers, an unseeded host gives `max(0, 0)`; reproduced with `phase_vocab.checkpoint` | §4.3: the seed is mandatory: a recorded floor before the next checkpoint, or a refused resume. Under line R the checkpoint loss is stated as today's limit, unchanged by the port |
| 2 | P2 | D3's zero-false-nudge bar on every `Unavailable` reason conflicts with the rules on `UnconfiguredBackend`; reproduced: all three approval cases nudged | §5.2: two expectations; the configured path is held to D3, the unconfigured path to the rules' differential |
| 3 | P2 | the rubric lets "Would you like me to continue?" be `asking_operator`, suppressing the control's nudge | §4: `asking_operator` requires the operator's answer to be necessary; `stopped_mid_task` explicitly includes unnecessary continuation questions |
| 4 | P2 | A2's strict replay belongs to P2.1, which P3.1/P3.2 don't wait for | §5: A2 depends on P2.1 and P3.3 |
| — | note | A3 counts stops while the cap counts queries; the cap can't prevent a later outage | query counts per profile; the cap needs ≥ 50 queries; A4 watches the rate and rolls back by unsetting the binding |

### Review of v3: REVISE (two P2) → v4

| # | sev | finding on v3 | v4 |
|---|---|---|---|
| 1 | P2 | the mandatory seed had no owner, and `--resume-force` bypasses the refusal v3 cited | §4.4: a reserved config key (`legacy_intervention_marker`, an ADR amendment in Amendment 5's form) lets the host count the marker in the journal; P0.7 owns the record and the floor fold; P3.2 the barriered write before the first step; P0.7 + P3.2 crash recovery; P2.3 enforcement, with force not skipping the seed and `DisabledDecision` when the count is unrecoverable |
| 2 | P2 | the last-3-turns state can drop the instruction that decides necessity; genuine and pre-approved histories serialized identically | §4: every user turn up to a total bound, a `context_complete` flag, a second Binary question (`requests_operator_input`), and abstention when context is incomplete and the candidate asks; §5.2 adds the paired genuine/pre-approved/invented cases |

### Review of v4: REVISE (one P2, two P3) → v5

Seed ownership was resolved on paper. Sol ran the real checkpoint on the real journal: the live marker count went 2 → 0 and the journal count stayed at 2.

| # | sev | finding on v4 | v5 |
|---|---|---|---|
| 1 | P2 | a checkpoint removes user turns before the guard sees them, so both paired sessions projected identically with `context_complete` true; reproduced through `phase_vocab.checkpoint` | §4.5: an operator-turn record that checkpoints don't fold, with authorship recorded when each turn is added (ABI 8.1 field + ADR amendment; P1.3x record, P1.4x view, P2.3 rebuild on resume). `context_complete` includes the record's `complete`; A3 depends on it |
| 2 | P3 | the seed keyed by `invocation_id` breaks once line X adds the occurrence | §4.4: `atom_key` = owner/site/local ID |
| 3 | P3 | raising only the total bound can't fix truncation by the task or one turn; those abstentions are invisible to the `Unavailable` cap | §4: `incomplete_reason`, defaults about 4×, A3 reports abstentions by reason and counts them as missed nudges; §5.2 long-session controls |

### Review of v5: REVISE (three P2) → v6

v5 tried to specify an operator-turn record inside the addendum, and the review showed three of its claims were wrong. v6 takes provenance out as a named prerequisite design, **P-OT**, with the findings as its acceptance criteria. P-OT's design and estimate are left to its own 031 document.

| # | sev | finding on v5 | v6 |
|---|---|---|---|
| 1 | P2 | the journal stores no author, and the host drops extra fields (reproduced through `SessionJournal.record`); feedback's extension isn't known where the loop adds the message | §4.5 P-OT R1 (durable authorship, order, seeds, start-of-session) and R3 (feedback attributed to its atom, threaded inside core) |
| 2 | P2 | operator input delivered by a wake is wrapped as `[motoko loop]`, so labelling wakes `Loop` drops it; reproduced with the real `wake_message` | P-OT R2: the wake's raw `OperatorInput` is an `Operator` turn, in run and after resume; §5.2 parked-wake pair |
| 3 | P2 | A0's `prepare` reading `ctx.operator_turns` fails `ailang check` on ABI 8.0 (reproduced) | A0 builds on 8.0 and reports `record` truthfully; new stage A0.1 moves it to 8.1 after P-OT; A3 depends on A0.1 |

## Governing docs

- `.agent/projects/031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md`: §0.9 (privacy), §1a (lines R/X), P1.3x, P1.4x, P2G, P3.1–P3.3, P3G, P4.1, §7 Q4, §8 (no live inference before a shadow run).
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`: D2, D3 (explicit absence, no identifiers on the wire), D5 (retained interventions), D6 (query identity and replay), D7 (digest).
- `.agent/projects/031_system_one_decisions/PLAN-001-addendum-progress-guard-on-jev.md`: the addendum, v1 as merged in #271.

## Predicted outcome

Nothing changes at runtime. The addendum on `main` becomes v6: five stages and **seven** operator decisions (§6). D6 (abstain on live `Unavailable`) and D7 (A1's private tier) are new. A0 (the stub-backed port) and A1 (the labelled set, in tiers) can still start now. A2 (offline), A3 (shadow, the first live call) and A4 (enforce) wait on line X.

## Test evidence

- **Review of v1:** Codex `gpt-6.1-sol` at high effort, read-only and unsandboxed. It returned REVISE with the six findings above. Findings 2 and 5 and the `ext_set_digest` claim were reproduced on temporary copies, and its `git status` was clean afterwards. It confirmed every other anchor and link at `602e1e4e`, the D3 fit of the Choice question, and the Jev 1.14 facts against OpenRouter, ZenMux and the SDK guide.
- **v2 anchors:** re-checked at `602e1e4e`. `types.ail:1981` is `| DecisionSolverJudge(`, and `runtime.ail:1578` is `ext_set_digest_sees_the_decision_variant_test`. The package's `[effects] max` is declared in its `ailang.toml`, which is consistent with finding 5.
- **Review of v2:** the same reviewer re-ran its reproductions. Results are in the table above. Its prototype also confirmed the threshold behaviour (8000 nudges, 7999 abstains, no distribution abstains even at confidence 10000) and that A0's registration-level scenario closes the direct-call gap.
- **Review of v3:** v2's findings 2, 3 (on paper; Jev unmeasured) and 4, and the outage note, are resolved; 1 partly, now finished in v4. The reviewer re-ran the matrix and budget cases on a scripted reference interpreter, not Jev.
- **Review of v4:** the full text was written by the reviewer to a scratch file and relayed. It checked the reserved-key amendment against Amendment 5, the owners against PLAN-001, and `--resume-force`'s consumers.
- **v5 anchors:** checked at `78f615a7`: `session.ail:1940` (`history_slice`), `runtime.ail:327-328` and `:372` (`invocation_id`), and PLAN-001 P1.3x/P1.4x.
- **Review of v5:** the reviewer wrote the full text to a scratch file. It re-ran the checkpoint, seed and bounds cases. It exercised the real `wake_message`, `SessionJournal.record` and an ABI 8.0 `ailang check`.
- **v6 anchors:** checked at `78f615a7`: `types.ail:1395`, `phase_vocab.ail:1109`, `journal.ail:854`, `session-journal.ts:666`, `session.ail:2850` and `:5043-5044`, `runtime.ail:879-882`.
- **Not done:** v6 has not been re-reviewed yet. `src/core/config.ail:130` (what `--resume-force` overrides) was read at `78f615a7`. Nothing here was executed: the design is a plan, and A0's tests are its first executable evidence.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
