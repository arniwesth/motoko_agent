# Motoko: where is the frontier of abstraction?

Status: scoped blog post, not a draft. Revised 2026-10-04 after the author
confirmed the central theme and asked to scope a post from the existing material.

This revision uses the [completed independent review](motoko-six-month-retrospective-review-claude-fable-5-1.md)
to correct chronology and narrow the narrative. The central theme is the author's;
section choices and word allocations below are editorial proposals for discussion.
The review and completed demo remain separate, unchanged artifacts.

## The post in one paragraph

A first-person account of trying to move from writing software to expressing an
idea and having a software factory carry it through. Motoko is both the agent being
built and an experiment in **Post-AI software engineering**: how to engineer
software when AI can carry much of the implementation, and what responsibilities,
practices, and tools that requires. The factory's intended reach includes software
systems beyond agents. DoomHouse made agentic coding
feel possible. Building Motoko in AILANG tested how far that possibility extended.
Collaboration exposed the need for a more reliable harness; deterministic simulation
testing made some of its behavior observable and reproducible. Building those
checks exposed another problem: a process can keep finding useful work without
finishing. Today, delegation through herdr and task graphs through dagr move the
experiment further, while failures of coordination and continuity reveal the next
responsibilities to make reliable. **Where is the frontier of abstraction? How far
and how high can we go?** The increasing speed of building and experimenting is
itself fun and addictive for the author. RSI gives the work a direction, with many
questions to explore along the way—including how the factory might help generate
and combine the ideas it works on, and how comparisons between versions could
guide its own improvement.

## Reader, promise, and argument

Write for technically curious developers exploring how AI changes software
engineering, including those building systems beyond agent harnesses. Assume
no prior knowledge of Motoko or AILANG. Target **2,800 words**, with a 3,000-word
ceiling excluding captions and references.

Open with the author's ambition:

> I don't want to write code and I don't want to look at code.

The reader should come away understanding what made that ambition more practical,
what still demands human judgment, and why the work increasingly concerns the
system around the model. The scope supports a research retrospective, with concrete
progress and unresolved problems. It does not establish a measured reduction in
human effort or reliable unattended operation.

Working argument: each responsibility successfully delegated exposes another one
that the system must carry reliably. Implementation leads to recovery and
verification, then coordination and deciding when work is complete. **A report of
success is not evidence of success** is a recurring lesson within that argument.
The frontier of abstraction remains the organizing question.

Use **Post-AI software engineering** in the author's confirmed sense: engineering
software once AI can carry much of the implementation. Motoko is the concrete
working example for exploring specification, architecture, verification,
coordination, and completion in that setting. The factory expresses the broader
engineering ambition; RSI is a stated destination within it. Keep the distinction
between intended applicability beyond agents and evidence gathered on Motoko.
The term supplies the frame, not an additional survey or a claim that the methods
have already been validated across other kinds of systems.

Preserve the pleasure of exploration throughout. The author describes building and
experimenting at increasing speed as “highly addictive and fun.” Introduce that
motivation alongside the opening quote and return to it at the end. Reliability
work supports the ability to try more things; the narrative should convey both
the difficulties and why the author keeps pursuing the experiment. This is the
author's experience of increasing speed, not a measured throughput claim.

AILANG's mutual influence with Motoko runs through the narrative: the language was
an intentional challenge, its types and effects shaped implementation, and Motoko's
requirements fed into upstream work. DST is the technical centerpiece, explicitly
inspired by **FoundationDB and Antithesis**. Recursive Self Improvement (RSI) is the
author's destination; stabilizing the factory is the present work.

## Narrative and word budget

| Section | Words | Responsibility coming into focus |
|---|---:|---|
| 1. From DoomHouse to a harder question | 300 | Expressing an idea and getting an implementation |
| 2. A fast first agent meets collaboration | 300 | Keeping a changing harness reliable |
| 3. DST makes reliability testable | 450 | Checking behavior across a sequence of events |
| 4. Building the checks creates a new stopping problem | 500 | Defining meaningful, bounded completion |
| 5. What that work bought: the DST demo | 350 | Knowing what a passing check establishes |
| 6. The factory has to remember its job | 450 | Delegation, continuity, and coordination |
| 7. The next frontier: learning what to try next | 450 | Comparative self-improvement and idea generation |
| **Total** | **2,800** | |

### 1. From DoomHouse to a harder question — 300 words

Start with the quote, then the concrete origin: DoomHouse, a Doom-like renderer
with rendering logic in ClickHouse SQL. Briefly describe Kilo in VS Code and
copy/paste between Google AI Studio and a SQL interpreter. The experience prompted
the author to push models harder and discover their limits.

Using more advanced harnesses led to wanting to build one. Knowing AILANG's
maintainer made a new language a deliberate part of the experiment: could agents
build a harness in a language the author believed was too new to be in their
training data? Keep that belief explicitly attributed. Introduce Pi and OMP only
if their names add something beyond “more advanced harnesses.”

Within this opening, name the broader experiment in Post-AI software engineering:
Motoko is a working example of how to build software when agents carry much of
the implementation. The practices being explored are intended to extend to
systems beyond agents. Establish that ambition and the central question without
making the reader learn the whole tool stack.

### 2. A fast first agent meets collaboration — 300 words

The first agent arrived quickly. Give early claim-verification work inspired by
ClaimCheck one sentence as an interest the author wants to revisit.

Publication and closer collaboration with the AILANG maintainer exposed the loose
architecture: PRs often broke the system. In the author's account, this was the
trigger for a major redesign with DST as a first-class concern. Compaction is the
following section's concrete example of the reliability problem.

Introduce AILANG as a developing foundation and a collaboration. Keep personal
motivations and recollections attributed to the author; do not invent a dated
redesign event or infer historical incidents from today's regression tests.

### 3. DST makes reliability testable — 450 words

Use compaction to explain why generating a plausible change is insufficient. The
author recalls lost instructions, corrupted context, provider exceptions, and
expensive repeated compaction. Choose **one** worked example: a context using
roughly 79% of the window can still be too large when a quarter must be reserved
for output. A summary that looks shorter can still leave the next request invalid.

Explain deterministic simulation in ordinary terms: exercise the production driver
with controlled environmental responses, faults, and time, then reproduce the
execution. Credit FoundationDB and Antithesis as inspirations without claiming
architectural equivalence. Fixed compaction regression tests provide the entry
point; generated worlds and replay extend the approach in the next section.

Explain the payoff for the central ambition: executable checks can support trust
in specific harness behavior as direct inspection decreases. Keep the boundary
clear: these checks do not establish the semantic quality of every summary or the
correctness of arbitrary generated code. Link the technical report for machinery.

### 4. Building the checks creates a new stopping problem — 500 words

Tell Project 009 once, in chronological order, with two connected difficulties.
This July–August work predates the first Motoko herdr extension commit and the
first dagr commit-message reference. Present it as an experience relevant to the
later factory, without assigning its orchestration to that later stack. Earlier
manual herdr use remains unestablished.

First, the ADR review loop: architecture was largely settled, but specification of
gate mechanisms kept generating corrections and further review obligations. Use
**154 findings across 19 review sections, nine correction passes, and no source
changes in the measured July 26–August 2 interval** as the one compact measurement.
Omit the seven-round delta series and extra statistics from the main prose.
Reviews found real problems; their individual usefulness did not make the overall
process converge.

Put the AILANG collaboration inside this episode. Motoko needed streamed output
both displayed immediately and recorded in exact order. Project records identify
the recorded-stream API as the external critical path and describe a prototype,
upstream work, release, and adoption. That is the concrete two-way example: language
constraints shaped Motoko's design, while Motoko supplied a requirement and work
that informed the language. Attribute this sequence to project records until
upstream details are checked; omit unverified PR-level credit and implementation
claims from publication.

Second, implementation checks kept exposing new gaps and expanding the queue.
On August 9, the finish line became a concrete record/replay demonstration plus
measured disclosure of extension limitations. New tasks blocked completion only
if they blocked those outcomes. The closing note is dated the same day. Six
remaining findings went to maintenance; the register contained 19 entries in total.

The narrative turn is that deciding what counts as completed work is itself part
of the responsibility being delegated. Avoid claiming that every question was
unverifiable or that the factory caused these earlier loops. Do not invent who
personally stopped them or what it cost.

### 5. What that work bought: the DST demo — 350 words

Use the **already completed October 4 run** as a short scene. Motoko executes a
scripted one-line source mutation that discards the successor state containing an
environment-read record. The read happened; its record was lost.

Build the scene around the diagnostic reporting one expected read and zero
recorded reads. Types and the four-seed corpus passed; recorded-program identities
changed; replay matched the incomplete recording. The separate completeness
assertion failed. Scripted restoration returned the source byte-for-byte to its
original state, restored the original identities, and made the gate pass.

Explain just enough to make the result meaningful: repeatability does not prove
completeness. The failing assertion uses an expectation derived from source and
control flow, rather than an independent runtime count of reads.

State the demonstration's boundary once: the edits were supplied in the prompt,
test subprocesses loaded the changed source, and no delegation was used. It shows
Motoko operating its own development tools under a prescribed procedure. It does
not demonstrate autonomous defect discovery, arbitrary repair, or modification of
its already-running process. Link the existing run note and scorecard; a new run
or video is unnecessary for this post.

### 6. The factory has to remember its job — 450 words

Introduce the current arrangement in one paragraph: Motoko coordinates work;
herdr provides delegation to agents such as Claude Code and Codex; dagr represents
tasks and dependencies; DST checks covered harness behavior. The author is using
this system while developing it. Attribute that broader practice to the author's
account; the demo is a separate, narrower observation.

Make the **lost orchestrator role** the concrete scene. The extension's incident
account records 10 delegation calls on September 12, followed by zero delegations
and 395 shell calls in a session resumed from a handoff on September 13. The handoff
carried work state but lost the instruction to act as an orchestrator. The response
was to persist the role and reinforce it through prompt and tool policy. Describe
that as an implemented response, without asserting that it guarantees compliance.

Connect this to the current challenge: delegation outcomes and the task graph must
stay synchronized, and a delegate's completion report needs supporting evidence.
This is where the frontier has moved: an agent must carry its responsibilities
across sessions and coordinate work toward a bounded objective.

Draw the broader engineering question from the incident: how should a factory
preserve roles, plans, and evidence while its workers and sessions change? Motoko
supplies the example; the question applies to the intended factory for other
software systems too.

Use the incident as evidence of the coordination problem and its response. The
existing material does not yet supply a complete account of a delegated
self-improvement from initial request through independently checked result. The
post can stand without that stronger case. Omit PR #215's proposed mechanics from
the main narrative; they add a second design discussion and are not established
here as shipped behavior.

### 7. The next frontier: learning what to try next — 450 words

Return to the author's motivation: building and experimenting at increasing speed
is addictive and fun. RSI remains the stated end goal, and the road toward it
contains worthwhile questions of its own. Stabilizing the factory supports this
exploration. Avoid making the ending merely an inventory of remaining problems.

Use **comparative self-evolution, Project 014**, to give that destination a concrete
research shape. Its proposal is to preserve alternative versions, their ancestry,
and their task results, use recurring failures and differences between versions
to suggest changes, and evaluate the candidates. Keeping this history allows
further experiments to branch from earlier versions. The first proposed steps are an archive linking versions
to outcomes and a report-only advisor; automated selection and modification come
later. This is a design-space exploration dated August 13, not evidence that an
evolution loop has since been built.

Connect it back to DST: covered deterministic checks could reject some broken
candidates before expensive benchmark evaluation. Where a failure can be reproduced
in a controlled simulated environment, comparing versions could help locate where
their behavior diverges. Passing those checks still does not establish improvement;
finding the first divergence alone does not explain a benchmark win. The note also
proposes keeping the evaluator fixed during a round of improvement and reviewing
changes to it separately, so a candidate cannot simply relax its own test.

Allocate roughly 180 words to this bridge. Refer to research on archives and
comparative evolution without cataloguing the Gödel-Machine lineage. Explain the
proposed mechanism in Motoko's terms; no external superiority, performance, or
proof claims are needed to make the connection.

Then widen the question with **the idea factory, Project 015**. The opening
ambition starts with a person supplying an idea; this research asks how the system
might help create and combine ideas, then choose which deserve an experiment.
The notes explore matching a recorded weakness with a new capability, mapping an
outside concept onto Motoko, and discovering connections between existing ideas.
Use one accessible example or question rather than introducing an operator taxonomy:
could a new language capability answer a standing research question?

The two projects connect at different levels: 014 explores using results to guide
changes to the harness; 015 explores generating and evaluating research directions,
including directions that change what is being measured. Neither makes the human's
choice of objectives disappear. Use about 150 words for the idea factory, leaving
the remaining space for motivation and the closing question.

Keep creativity and evaluation together: make room for unexpected directions,
try ideas cheaply, and learn from the outcome. Project 015 describes an existing
manual research process and proposals for making generation, combination, and
evaluation more explicit. Its notes explicitly defer automating generation and
selection; this is an exploration direction, not a shipped autonomous idea engine.

End with the frontier moving into the choice of what to build and investigate.
Connect that to the broader Post-AI software engineering experiment: how far can
the process from an idea to a working software system be entrusted to the factory?
Human judgment remains part of the present process. RSI is the destination;
neither this research nor the scripted demo establishes that it has been achieved.
The closing mood should carry the author's curiosity and enjoyment, without
inventing a commitment to fully automate creative direction.

## Assets and cuts

Use at most one main visual: a small scorecard beside the demo, showing changed
identities, passing replay, and the failing completeness assertion. Use the
existing run artifacts. A factory diagram is optional only if it makes the
coordination paragraph easier to understand.

Keep detailed DST architecture, fault catalogues, full review statistics, migration
counts, tool comparisons, PR mechanics, and the deeper ClaimCheck thread in linked
material or future posts. Idea-factory schemas, operator catalogues, and evaluation
metrics also remain linked material. Project 014's literature survey, benchmark
numbers, historical gap counts, and claims of superiority stay out of the post;
the closing section uses its proposed approach to explain a research direction.
No new experiment, review, video, or agent run is needed to support this scope.

## Evidence to carry into drafting

| Claim or episode | Starting source |
|---|---|
| DoomHouse and its implementation | [DoomHouse repository](https://github.com/arniwesth/DoomHouse); author's account for workflow and motivation |
| AILANG | [AILANG repository](https://github.com/sunholo-data/ailang) |
| Motoko's recorded-stream requirement and prototype | [Upstream request text](../.agent/projects/009_motoko_dst_execution/ISSUE-BODY-recorded-stream-api.md) |
| AILANG release enabling Motoko's next step | [Release/adoption handoff](../.agent/projects/009_motoko_dst_execution/HANDOFF-post-upstream-recorded-stream-landing.md), including its dated status corrections |
| AILANG shaping migration and trace integration | [Toolchain migration report](../.agent/projects/009_motoko_dst_execution/NOTE-b1-execution-report-and-plan-corrections.md) and [stream-parity integration report](../.agent/projects/009_motoko_dst_execution/NOTE-c3-execution-report-and-plan-corrections.md) |
| Early claim-verification inspiration | [ClaimCheck article](https://midspiral.com/blog/claimcheck-narrowing-the-gap-between-proof-and-intent/) |
| FoundationDB and Antithesis as DST inspirations | Author's account; [technical report §2.1](../papers/motoko-dst-report/DRAFT-3.md#21-deterministic-simulation-and-neighboring-methods) provides background and primary references |
| Overall DST architecture and limits | [Integrated technical report](../papers/motoko-dst-report/DRAFT-3.md), a September 19 snapshot; verify present-tense claims against source |
| Compaction cases | [Long-session scenarios](../scripts/dst/long_qwen_compaction_dst.ail), especially `scenario_multiple_compactions`, `scenario_output_headroom_exact_boundary`, `scenario_artifact_cache_stable`, and `scenario_hostile_summary_preserves_control_capsule` |
| Motoko demonstrating DST on its own source | [`demo_dst` target](../Makefile), [demo prompt](../.agent/notes/DEMO-dst-self-test-prompt.md), and [observed run and scorecard](motoko-dst-demo-run-2026-10-04.md) from 2026-10-04 |
| Review-loop counts and interpretation | [Project 009 retrospective](../.agent/projects/009_motoko_dst_execution/NOTE-review-loop-retrospective.md) |
| Growing queue and bounded completion rule | [Project 009 implementation plan](../.agent/projects/009_motoko_dst_execution/PLAN-implementation-deterministic-test-world.md), “The goal line” |
| Completion with disclosed remaining work | [Project 009 closing note](../.agent/projects/009_motoko_dst_execution/NOTE-d28-the-final-acceptance-rerun.md) |
| Persistent orchestrator role | [herdr orchestrator implementation](../packages/motoko-ext-herdr/orchestrator.ail), opening incident account |
| Observed delegation state versus verified results | [dagr producer](../packages/motoko-ext-herdr/dagr.ail), evidence-tier rules; a delegate reporting completion is not independent verification |
| Proposed authoritative plan structure | [PR #215](https://github.com/arniwesth/motoko_agent/pull/215), including its D8 amendment |
| Enjoyment of faster building and experimentation; RSI as the destination with further exploration along the way | Author's account in the scoping discussion, 2026-10-04; subjective experience, not a speed measurement |
| Post-AI software engineering as the broader experiment, extending to systems beyond agents | Author's explicit confirmation in the scoping discussion, 2026-10-04; intended scope of the factory, not demonstrated cross-domain validation |
| Idea factory as a research direction, with generation and selection automation deferred | [Idea-factory research](../.agent/projects/015_idea_factory/RESEARCH-idea-factory-and-idea-evaluation.md), especially §§0, 3, 7; [generation and combination research](../.agent/projects/015_idea_factory/RESEARCH-idea-generation-and-combination-operators.md), especially §§1–3, 8; [combination discussion](../.agent/projects/015_idea_factory/NOTE-idea-creation-and-combination.md) |
| Comparative self-improvement as a proposed direction: archive, comparisons, DST checks, and separate evaluator changes | [Project 014 research](../.agent/projects/014_comparative_self_evolution/RESEARCH-godel-machine-lineage-for-motoko.md), especially §§3.1, 3.3–3.4, 6–7; August 13 research proposals, not current implementation evidence or independently verified literature claims |

The project-009 statistics above are historical measurements reported in the
records, not independently reconstructed git-history measurements in this session.
The focused inspection ran three compaction-policy scenarios and nine host-boundary
tests successfully; it was not a full DST validation and should not be presented as
one in the post.

## Remaining author input and publication checks

The outline can be drafted from the existing material. These are narrow finishing
questions, rather than prerequisites for expanding the research:

- **Author's ending supplied:** the enjoyment of faster building and experimenting,
  with idea generation as one direction along the road to RSI. This supports the
  closing section without requiring a claim that the factory is ready for
  unattended operation.
- **RSI:** confirm a one-sentence definition if the post goes beyond naming it as
  the destination. Do not substitute an editorial definition for the author's.
- **Duration:** use the title above without “six months.” Restore a duration only
  after the author anchors pre-publication work; the May 3 public release alone
  does not establish six months by October 4.
- **AILANG attribution:** before publishing precise upstream dates, contributions,
  and credits, verify them against the upstream record. The current sources are
  Motoko's project records. Agree factual wording and credit with the author.

Exact early dates, the identities of agents in the 009 loops, personal cost figures,
and a complete delegated self-improvement case can enrich the post if already
available. They are not required by this outline; unsupported details stay out.

This document authorizes no publication and contains no full blog draft. The next
writing step is a first-person draft within this scope when the author requests it.
