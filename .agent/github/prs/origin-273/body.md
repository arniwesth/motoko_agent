---
repo: arniwesth/motoko_agent
pr: 273
branch: docs/034-plan-001
ticket: null
title: "docs(034): ADR-001 accepted as amended; PLAN-001 for effect disclosure"
---

## Summary

ADR-001 for project 034 (effect disclosure for tool faults) moves from Proposed to **Accepted, as amended**. Before the operator ruled on 2026-10-17, it was re-grounded at `e69aaad7` on AILANG v0.52.5. The PR adds that re-grounding, the operator's five rulings, probe evidence on the pinned binary, and **PLAN-001**: 26 tasks with a `dagr` graph. Phase 0, the live change that gives every tool fault the model reads a `fault` object with `effects: none | unknown`, is ready to implement. Two independent reviews followed. Codex Sol found 8 issues, fixed in `fb2d28b8` (v1.1). Claude Opus 5.5 found 19, fixed in `bc386843` (v1.2). Each review had one blocking finding, and every finding that could be checked against the code was reproduced (*Review*, below). Docs and evidence only; no source changes.

## Changes

- docs(034): ADR-001 accepted as amended; PLAN-001 for effect disclosure
- chore(github): PR #273 record
- docs(034): PLAN-001 v1.1 — the eight findings of the Codex Sol review
- chore(github): PR #273 record — an independent review by Codex Sol: one blocking finding and seven others, all fixed in fb2d28b8
- docs(034): PLAN-001 v1.2 — the nineteen findings of the Claude Opus 5.5 review

8 files changed.

- **ADR-001**
  - The status line now reads Accepted.
  - §6 *Rulings* records the operator's five rulings:
    1. D1–D9 accepted as amended.
    2. `NotAllowed` → `none`.
    3. `PermissionDenied` → `unknown`.
    4. The upstream asks are filed.
    5. The deterministic suites are the eval baselines.
  - Each affected decision has a "Ruled" note.
  - §7 records the re-grounding: anchors that moved, and facts the ADR did not have. Two examples: P3 is not covered by 011's `DriverStepRepeated`, and P1/P3 move `invariant-set/2` → `/3`.
- **evidence/start_probe.sh** (new): cases 13–21, `NotAllowed` and `PermissionDenied`.
- **evidence/RESULTS-v0.52.5.md**: cases 1–21 on v0.52.5. The upstream state is also recorded: v0.54.14 kills the process group on timeout.
- **PLAN-001-effect-disclosure.md** and **PLAN-001.dagr.json**:
  - Workstreams W0, W0b and W1–W3, one per ADR phase.
  - Phase 0's mutants (m01–m15) and live witness rows are named in advance.
  - Five choices the ADR left open (C1–C5) are argued. C1 keeps `tool_phase.ail` out of Phase 0, so the anchor/profile-hash cascade is paid once, in Phase 1.
- **NOTE**: the status line points at the accepted ADR.
- **REVIEW-001-plan-001-codex-gpt-6.1-sol.md** and **REVIEW-002-plan-001-claude-opus-5.5.md**
  (new): the two independent reviews, kept beside the plan. The plan's *Review* section gives each
  finding's reproduction and disposition.

Filed upstream the same day, under ruling 4: sunholo-data/ailang#1878, #1879, #1880.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md`
- `.agent/projects/034_ambiguous_tool_outcomes/NOTE-scope-effect-unknown-tool-faults.md`
- `.agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md`
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/RESULTS-v0.52.5.md`
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`
- `.agent/projects/008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md` (D2, D3: plan structure lives in the dagr document)

## Predicted outcome

- **Code:** none from this PR.
- **The plan becomes the work queue.** Tasks are addressed as `034/PLAN-001/<id>`, and `W0.1` (record the `make dst` and `make eval_matrix` baseline) is the first ready task.
- **How it will be checked:**
  - A reader can find every ruling in ADR §6.
  - A reader can reproduce every measured claim with the two evidence scripts.
  - `dagr check --strict` stays clean on the graph.
- **What would show the plan wrong:** Phase 0's own gate, W0.7, finding a changed DST or eval-matrix row beyond the ones the plan lists.

## Test evidence

- `dagr check .agent/projects/034_ambiguous_tool_outcomes/PLAN-001.dagr.json --strict` → `✓ clean — 26 tasks, 0 attempts, 0 events` (dagr 0.3.1), at `fb2d28b8` and at `bc386843`.
- `bash .agent/projects/034_ambiguous_tool_outcomes/evidence/exec_probe.sh` on AILANG v0.52.5 (`7200786`):
  - cases 1–12 match the v0.47.2 results recorded in the NOTE and ADR;
  - the full table is in `RESULTS-v0.52.5.md`.
- `bash .agent/projects/034_ambiguous_tool_outcomes/evidence/start_probe.sh` on v0.52.5:
  - cases 13–14 return `NotAllowed` with no launch trace;
  - cases 15–17 and 20–21 return `PermissionDenied`, and the target program never ran;
  - cases 18–19 return `Ok`.
- `NotFound` under `DEBUG_PROCESS=1` on v0.52.5: both cases return `Err(NotFound(...))` with no `[process] start` line, and the marker is absent. This is recorded in `RESULTS-v0.52.5.md`.
- Standalone reproductions for the upstream issues were run on v0.52.5. One case is new: exit 7 with a held pipe returns `Ok exitCode=7`, while exit 0 with a held pipe returns `SpawnFailed`. This is recorded in `RESULTS-v0.52.5.md`.
- No source changed, so `make check_core` / `make dst` were not run. Phase 0's W0.1 records them as the baseline.

## Review

### First review

An independent review by Codex Sol (`gpt-6.1-sol`, reasoning effort xhigh) on 2026-10-17, of head `2cf82955`. It ran in its own detached worktree, read-only, and was given none of the author's conclusions: `.agent/projects/034_ambiguous_tool_outcomes/REVIEW-001-plan-001-codex-gpt-6.1-sol.md`.

- **Verdict:** **merge after the listed fixes.**
- **Probes:** it re-ran both probe scripts on v0.52.5, and cases 1–21 matched.
- **One limitation, the author's fault.** The brief told it to read the diff first, and the diff contained this PR record, so it saw this description before drafting. Its findings do not cite the description.

| # | Finding | Reproduced by the author | Disposition |
|---|---|---|---|
| 1 | **Blocking.** W1 gave no route by which `applied` survives persistence and replay without entering the served payload. Replay rebuilds tools only from that payload, and property P2's comparison keys on it, so every twin pair would differ. | Yes: `dst_program.ail:243-252`, `dst_replay.ail:761-772`, `dst_invariants.ail:2242-2244`. | **Fixed in W1.2.** `applied` goes in a world-truth field of `ExecutionProgram`, never the payload; the stage stays in the payload. The plan adds recording, replay, twin and version rules, and three acceptance rows. |
| 2 | **Should fix.** A long `cmd` renders before `fault` and can push it past the 65,536-code-point cap. | Yes: `tool_dispatch_adapter.ail:136-142`. | **Fixed in W0.3.** `fault` comes right after `tool`, and a long-command test is added. |
| 3 | **Should fix.** The `none` sentence said nothing ran, but a failed Search may have run `rg`. The `unknown` sentence said the tool started, but `PermissionDenied` almost certainly did not. | Yes. | **Fixed in C3.** Both sentences are reworded and pinned in tests. |
| 4 | **Should fix.** Stated rules without a mutant: all of W1's validators and guard, W3's counts, W0's kind mapping and refusal sites, and W0b's output preservation. | Yes. | **Fixed.** W0.6 grows to m01–m29, with witness rows i–o to catch the new ones, and W0b.4 gains w5. New tasks W1.7 (v01–v16) and W3.2 (r1–r3); the gates move to W1.8 and W3.3. |
| 5 | **Should fix.** The generator bump to `"2"` collapses the seeded suite's `versioned` row, which already uses `"2"`, and leaves two fixtures unpinned. | Yes: `seeded_generator_dst.ail:1228`. | **Fixed in W1.6.** The row moves to a different version with an asserted inequality, and both fixtures are re-swept. |
| 6 | **Minor.** W3.1 listed counts that the new `AlwaysApplicable` rows do not move. | Yes. | **Fixed.** |
| 7 | **Minor.** The plan and the graph disagreed on whether witness rows e and f, unevaluated under root, block the gate. | Yes. | **Fixed.** Merge acceptance needs a run as a non-root user. |
| 8 | **Minor.** ADR §7 said 31 `generator_version` sites; there are 17. | Yes. | **Fixed** in ADR §7 and W1.6. |

### Second review

An independent review by Claude Opus 5.5 (`claude-opus-5-5`, effort xhigh) on 2026-10-17, of head `25748655` (v1.1). The file is `.agent/projects/034_ambiguous_tool_outcomes/REVIEW-002-plan-001-claude-opus-5.5.md`.

- **How it ran.** In its own detached worktree, read-only. It left out this description, and drafted its findings before reading the first review.
- **Verdict:** **merge after the listed fixes.**
- **Phase 0:** sound and implementable now.
- **v1.1's fixes:** first-review findings 2 and 6 fixed completely; 3 and 7 right; 1, 4, 5 and 8 incomplete.

All 19 findings are addressed in `bc386843`. Each one I could check against the code at `e69aaad7` reproduced. Findings 10 and 15, and finding 5's matrix outcome, are the reviewer's own inferences.

| # | Severity | Finding | Disposition |
|---|---|---|---|
| 1 | **blocking** | Every native dispatch round-trips the world through the extension token (`tool_phase.ail:436-437`, `ext_world.ail`), so `applied` and the effect log would be reset mid-run. | W1.3: world truth never enters the token. It is re-seated from the pre-hook world after adoption. New round-trip rows and mutants v19–v21. |
| 2 | should-fix | The bank's denials come from `session.ail`'s `policy_denied_message`, not `tool_phase`'s builder. | W1.4 covers five builders. W0.3 adds the defensive dispatch arm. W2.1 names the builders P1's presence check covers. |
| 3 | should-fix | The world-truth encoding and where its rejections run were unstated. | W1.2: a version-gated required line. Stage-dependent rejections run in `world_state_of`. |
| 4 | should-fix | W1.2 needed W1.3's outputs. | The two tasks are re-cut. |
| 5 | should-fix | ADR-004 protected symbols and journal files; `eval_matrix` rows would move unpredicted. | The surface names them. W1.1 predicts the rows and arranges `manifest-A`; W1.8 checks the list. |
| 6 | should-fix | The journal remedy had no fixture. | W1.4: a pre-W1 journal fixture, admitted by A2 and K7. |
| 7 | should-fix | The duplicate-effect metric would read 0 where it matters. | W1.3 logs every applied effect. W3.1 drops the live/journal claim. |
| 8 | should-fix | The canary's "next version" would equal the current one. | W1.6: the pair moves to versions 2 and 3. |
| 9 | should-fix | Mutation gaps remained after v1.1. | m30–m35 and row p; v12 rewritten; v15–v22; ws1–ws5. |
| 10–19 | minor | P3 and provider-reused ids; row o reachable; test mechanics; recording details; the gate scope; the lexical guard's home; the stage default's reason; `make dst` cost; prose/graph mismatches; comment lines cited as sites. | All addressed. The plan's Review section has a row for each. |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
