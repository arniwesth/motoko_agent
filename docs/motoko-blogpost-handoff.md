# Handoff: Motoko six-month retrospective

Prepared 2026-10-04 for a fresh Codex Astra session, at the user's request after usage resets and a long conversation. Repository: `/workspaces/motoko_agent`. This is a continuation of a writing discussion, not authorization to produce or publish the full blog automatically.

## Start here

1. Read this document, then `docs/motoko-six-month-retrospective-scope.md`.
2. Read the completed independent review, `docs/motoko-six-month-retrospective-review-claude-fable-5-1.md`. The user explicitly requested this through herdr, in a separate document. It is complete; do not commission another review.
3. Briefly tell the user you have picked up the discussion and summarize the most consequential review findings. Continue discussing/refining the scope as directed. The review has **not** been applied to the scope. Do not silently treat all reviewer opinions as author decisions.

The immediate user request was: “I used one more reset. But this session has become long. We need to hand it off to a new codex astra session using herdr”. Before that: “Use hedr to delegate to claude fable 5.1 to review docs/motoko-six-month-retrospective-scope.md. The review should be in a seperate doc”.

## The author's story and intended argument

- DoomHouse (<https://github.com/arniwesth/DoomHouse>) was the first demonstration of agentic coding: Kilo in VS Code and copy/paste between Google AI Studio and a SQL interpreter. It is a ClickHouse/SQL game-rendering project.
- Next ambition: push models hard enough to discover their limits. The author knew the AILANG maintainer (<https://github.com/sunholo-data/ailang>), was using more advanced harnesses such as Pi and OMP, and wanted to build a harness. Building it in AILANG, believed then too new to be in model training data, was an intentional challenge. Present the training-data claim as the author's premise, not a verified fact.
- The first agent was built quickly. Early experiments included claim verification inspired by <https://midspiral.com/blog/claimcheck-narrowing-the-gap-between-proof-and-intent/>. The author wants to revisit that work more deeply later.
- After publication as `motoko_agent`, closer work with the AILANG maintainer exposed loose architecture: many PRs broke things. This prompted a major architectural redesign and first-class deterministic simulation testing (DST).
- Compaction was a prime DST target. The author's recollection: corrupted context, lost system prompts, still-too-large contexts causing provider exceptions, and repeated expensive compactions. Regression scenarios demonstrate tested properties; they alone do not establish dates of historical incidents.
- DST is the “crown jewel”, inspired explicitly by **FoundationDB and Antithesis**. It must feature prominently, but serve the larger question rather than turn the post into a test-system specification.
- Central quote/intention: **“I don't want to write code and I don't want to look at code.”** The desired software factory accepts ideas with minimal human involvement. **Where is the frontier of abstraction? How far and high can we go?**
- herdr and dagr were a major step. Plans expressed as graphs; Motoko orchestrates Claude Code/Codex and participates in building itself, thereby dogfooding itself. Correct product spelling is **herdr** despite occasional user “hedr”.
- **Recursive Self Improvement (RSI)** is the stated destination. Current work is stabilizing the factory (Motoko + other agents + herdr + dagr), not claiming achieved open-ended autonomous RSI.
- Current problems: keeping delegation and the dagr graph synchronized; preventing infinite task generation to verify things that may be unverifiable. Project 009 was the author's concrete example of tasks continually being added.
- **Mutual influence between Motoko and AILANG** must run through the narrative. AILANG was not simply an obstacle. Motoko's demands led to upstream changes; language types/effects and evolving APIs shaped Motoko's architecture.

## Documents and ownership

Created in this session, currently uncommitted/untracked:

- `docs/motoko-six-month-retrospective-scope.md`: scope, working thesis, outline, evidence and open questions. Not a finished blog.
- `docs/motoko-dst-demo-run-2026-10-04.md`: detailed observed execution and limitations.
- `docs/evidence/demo-dst-2026-10-04.txt`: filtered actual native tool output and final runtime summary, excluding model narration.
- `docs/motoko-six-month-retrospective-review-claude-fable-5-1.md`: independent review, now complete.
- This handoff.

The scope was compared byte-for-byte with `/tmp/motoko-blog-scope-before-review.md` after the review and was unchanged. There are many unrelated working-tree modifications and untracked files from other work, including Makefile, ailang.lock, tools/code-graph and .agent projects. Preserve them. No commits or PR changes were requested. Root AGENTS.md is empty; no docs/AGENTS.md was found.

## Independent review: complete

Launched through herdr, agent **blog-scope-review**, pane **wD:p2**, cwd this repository:

`herdr agent start blog-scope-review --kind claude --pane wD:p2 --timeout 30000 -- --model claude-fable-5-1 --allowedTools Read Glob Grep Write`

Claude session `e75f1748-9ed9-48ec-8f57-eaaee4b123ed`. Last observed status **done**. Explicit requested model confirmed in launch arguments; no independent backend attestation. Task text: `/tmp/motoko-blog-scope-review-task.md`. Output exists at the separate review path above. Reviewer inspected sources and read-only git history; no tests run. Leave its pane available.

Most consequential findings (read the actual document for sources and distinctions between evidence and opinion):

1. Project 009's July/August loops preceded the first Motoko herdr extension commit (Aug 23) and first dagr commit-message reference (Aug 30). The title “failure of the factory” risks anachronism. Earlier manual herdr usage is not ruled out. Present 009 as an experience the later factory responds to.
2. Current outline tells overlapping weeks twice. Suggested sequence: compaction/DST → 009 with AILANG API collaboration inside it → demo as payoff → current factory/RSI.
3. Too much material for ~3,000 words. Suggested ~2,850-word outline, one compaction example, shorter tool-name introductions. Promote the lost-orchestrator-role incident as a concrete factory story.
4. Proposed sharper theme: a report of success is not evidence of success. This is editorial advice, not an author-approved replacement thesis.
5. Be precise about 154 findings / 19 review sections / 9 correction passes / 7 delta-review rounds. Architecture was largely settled; review churn concerned gate mechanisms. Closing residue included six findings moved to a 19-entry maintenance register.
6. “Six months” needs author dates: initial public release May 3 is five months before October 4, with pre-publication work not dated. Distinguish collaboration failures as redesign trigger from compaction as example.
7. Demo's program identities changed under mutation even though corpus passed. Keep “scripted” attached to edits. AILANG upstream contribution details should be checked upstream before publication. Reviewer did not read the raw demo log or upstream PRs.

No scope changes have been made based on these findings. Avoid turning this review into another unbounded review loop.

## Actual `make demo_dst` run — already complete

The user specifically asked us to run and understand it. We did, to completion:

`env -u MODEL MOTOKO_HEADLESS=1 TERM=xterm make demo_dst`

Exit 0; model `openrouter/xiaomi/mimo-v2.6-pro`; ~16m50s; 12 provider calls; runtime finish_reason stop, no runtime error. Launch HEAD `cf54dff9`, working tree otherwise dirty. Do not rerun for handoff/review: it costs money, mutates a source file temporarily and uses shared `/tmp/motoko-dst-demo`. A pre-existing concurrent demo collided with that shared directory; the other run stopped before mutation and only ours was active when we mutated. No code fix for that operational weakness was made.

Read the run note and evidence extract for the full scorecard. Key observations:

- Generator seed 13 repeated with 24 operations gives digest 864106749; seed 12 gives 484525277. Seed-ignored negative-control canary passes.
- Epoch 42, seeds 13–16, `driver_only/32`: separate processes reproduced program identities. Seed 13 hit approval denial; seed 15 hit tool deadline and approval denial; two seeds reached no injected fault.
- Prompt supplied a **scripted one-line mutation** in `src/core/session.ail`, `session_policy_init` around line 2354: the next `OPENAI_BASE_URL` env read advances `r_persist.next_state` instead of `r_retry.next_state`. That throws away the successor state containing the `MOTOKO_RETRY_STREAM_ERROR` read's record, though its value was obtained. Types still accept the stale state. New subprocesses load the changed source; the already-running agent is not hot-patched.
- Mutant compiler passes; generated four-seed corpus passes; rich scenario ends Ok; exact replay and terminal outcome agreement pass. But the recording has 30 interactions, and a **separate source-derived completeness assertion** expects one `MOTOKO_RETRY_STREAM_ERROR` read and finds zero. `make strict_replay` fails (exit 2).
- Diagnostic: `[discovery-env-read-under-recorded] ... 1 read(s) of 'MOTOKO_RETRY_STREAM_ERROR' and log records 0 ...`. This is provenance/source-control-flow evidence, **not** a runtime capability witness. Both execution and replay can agree on an incomplete record; agreement alone cannot prove completeness. Do not say no read executed: it executed but was lost from carried world state.
- The shell tool wrapper returned 0 because later echo/grep commands masked the gate's exit status. Distinguish wrapper status from the actual failing gate.
- Scripted restoration made `src/core/session.ail` byte-identical to original backup and git HEAD. Restored compiler/corpus/strict replay pass; 31 interactions; original identities return.
- Demo has 11 catalogued classes and 4 qualified gaps, no extension profile, no delegated agents. It proves neither arbitrary autonomous repair nor full factory RSI.
- Automatic end verifier `make check_core` ran, but stdout verdict was not surfaced. The verifier has fail-open paths; do not claim an independently witnessed full check_core pass. Zero cost telemetry is not proof of no provider cost.

Artifacts:

- Raw session `.motoko/logfile/session_1791114342309-8f538e40c49b7fc5.{md,jsonl}`.
- Capture `/tmp/motoko-demo-review-187dumn3/` (run.log, original `session.ail.before`, artifacts, transcript copies).
- Source original/restored SHA256 `33151b8a570df892554aa0799170f71376767098238d4811adf9cee173e7ba9e`.
- Earlier focused checks: 3 compaction-policy scenarios and 9 host-boundary tests passed. No full DST suite run was claimed.

## Source map for selective follow-up

- `.agent/projects/009_motoko_dst_execution/NOTE-review-loop-retrospective.md`: July 26–Aug 2 ADR loop, 154 findings, 19 review sections, 9 correction passes, 24 commits, no source changes during measured period. Delta round counts 15,12,16,16,17,19,20. Architecture stable for eight rounds; self-regenerating “correction not independently verified”.
- Same directory `PLAN-implementation-deterministic-test-world.md`, “The goal line”: by D23 more findings kept creating tasks. Bounded finish became effectful composed session record/replay plus measured classification of 15 extensions as mediated or disclosed. New tasks only if blocking those; rest maintenance.
- `NOTE-d28-the-final-acceptance-rerun.md`: Aug 9 close, 11 acceptance rows with qualified profiles; six findings deferred, maintenance register 19 entries.
- `ISSUE-BODY-recorded-stream-api.md`: need immediate chunks and exact ordered returned chunks under callback/effect constraints.
- `HANDOFF-post-upstream-recorded-stream-landing.md`: historical evidence of v0.33.0 recorded-stream API, upstream collaboration and migrations. It is **not current executable instructions**. Upstream #546/#577 details remain to verify externally before publication.
- `NOTE-b1-execution-report-and-plan-corrections.md`, `NOTE-c3-execution-report-and-plan-corrections.md`: compiler/type/effect migration evidence.
- `papers/motoko-dst-report/DRAFT-3.md`: integrated Sept 19 snapshot at 7e5ec5f9, architectural account and FoundationDB/Antithesis references.
- `scripts/dst/long_qwen_compaction_dst.ail`: system digest through >=3 compactions, tool pairing, misleading summary vs control capsule, cache reuse, 79%-full context with output headroom reservation.
- `src/core/ports.ail`, `src/core/session.ail`, `src/core/step_machine.ail`: explicit WorldState, real production driver, pure decisions. Generated worlds/faults/time/replay test runtime contracts, not universal model correctness.
- `packages/motoko-ext-herdr/orchestrator.ail` header: Sept 12 delegation, Sept 13 handoff lost role, implementation via 395 BashExec/zero delegation; persisted role and tool policy response. Policy is not a sandbox.
- `packages/motoko-ext-herdr/dagr.ail`: observed facts and reported delegated work distinguished from independent verification.
- PR #215 <https://github.com/arniwesth/motoko_agent/pull/215>: inspected as a **draft documentation/design PR**, SHA 857ed019e7f74e8b0901fd46777ff9b4cfb8dea9. Committed dagr JSON authoritative plan vs local run state; D8 guards started-task acceptance-term edits with authorized directives. Do not present proposed implementation as shipped based on this PR. Recheck only if publication needs current status.

## herdr routing and workspace cautions

Current old conversation pane **wD:p1**, reviewer **wD:p2**, tab **wD:t1**. The inherited HERDR_WORKSPACE_ID=w1 / TAB=w1:t5 / PANE=w1:p6 are stale. Always use explicit discovered pane IDs; do not use `--current` or assume focused pane belongs to this task. User may be active elsewhere.

Installed herdr 0.8.2/protocol 20. `herdr --skill` was read in the preceding session. Read it in the new session before controlling herdr if not inherited. Useful commands: `herdr agent get blog-scope-review`, `herdr agent read blog-scope-review`, `herdr agent list`. Do not interrupt, close or repurpose unrelated agents. The new session should continue in this shared checkout and preserve others' work.
