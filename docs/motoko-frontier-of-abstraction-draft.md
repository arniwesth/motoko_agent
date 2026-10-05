# Motoko: where is the frontier of abstraction?

*Working draft, October 4, 2026. Written as material for the author's own version.*

I don't want to write code and I don't want to look at code.

That is the ambition behind Motoko. I want to express an idea and have a software factory carry it through: work out what needs to change, implement it, check the result, recover from failures, and finish. Each part I can entrust to that factory gives me more room to think about what to try next.

Building and experimenting at increasing speed is highly addictive and fun. An idea can become something I can run, question, and change while the curiosity that prompted it is still fresh. Recursive Self Improvement—RSI—is the stated end goal, and there is a great deal to explore along that road.

The question running through all of it is: **where is the frontier of abstraction? How far and how high can we go?**

My first demonstration of what agentic coding could make possible was [DoomHouse](https://github.com/arniwesth/DoomHouse), a Doom-like renderer whose rendering logic runs in ClickHouse SQL. I used Kilo in VS Code and copied code between Google AI Studio and a SQL interpreter. It was a very hands-on arrangement, but it made an improbable project tangible.

I wanted to push harder and find the models' limits. Using harnesses such as Pi and OMP made me interested in building one myself. I knew the maintainer of [AILANG](https://github.com/sunholo-data/ailang), a language designed with AI coding in mind, and chose it deliberately as a challenge. At the time, I believed it was too new to appear in the models' training data. That was my premise for the experiment; I had no way to inspect their training datasets.

Motoko grew out of that experiment. It has also become my working example of **Post-AI software engineering**: how we engineer software once AI can carry much of the implementation, and what responsibilities, practices, and tools that leaves us needing. The factory I am exploring is intended to build systems beyond agents. Building an agent gives me a concrete place to develop and test those ideas.

The first agent came together quickly. Early experiments included claim verification, inspired by [ClaimCheck](https://midspiral.com/blog/claimcheck-narrowing-the-gap-between-proof-and-intent/): examining whether a formalized guarantee actually expresses the intent behind it. That remains a thread I want to revisit more deeply.

Getting an agent running opened up many possible directions. It also meant the thing doing the work had become another system to understand. A harness has to carry instructions, conversation state, model responses, tool calls, and failures through a continuing sequence of decisions. Its behavior depends on what happened earlier and on what the outside world does next.

After I published `motoko_agent` and began working more closely with AILANG's maintainer, the loose architecture became a serious problem. PRs frequently broke things. Collaboration exposed how difficult it was to change one part with confidence about the rest. That prompted a major architectural redesign, with deterministic simulation testing as a first-class concern.

AILANG was part of that development in both directions. Its types, effects, and APIs shaped the designs available to Motoko. Motoko's requirements, in turn, exposed things the language and runtime needed to support. The language was becoming a foundation through use and collaboration, while the agent supplied demanding cases for it.

That relationship matters to the larger experiment. The factory depends on the tools and representations through which it works. A language can make some mistakes visible, some operations explicit, and some changes easier to check. Building the harness revealed where those properties helped and where the surrounding machinery still needed work.

Compaction made the reliability problem especially concrete. Long-running agents need to reduce the conversation they carry forward. My recollection of the early failures includes corrupted context, disappearing system prompts, contexts that remained too large for the provider, and repeated compactions that became expensive.

A compacted conversation can look reasonable when read on its own. The important question is whether the agent can continue correctly from it. Instructions must survive. Tool interactions must still make sense. The next model request must fit. Those properties span a sequence of events, and a locally plausible edit can break the sequence.

One [regression scenario](../scripts/dst/long_qwen_compaction_dst.ail) makes the size problem easy to see. A request uses roughly 79% of a 262,144-token context window. That sounds comfortable until the request also reserves 65,536 tokens—a quarter of the window—for output. The total is too large. Reducing a conversation and leaving room for the next response are separate requirements.

This is where deterministic simulation testing, or DST, became the crown jewel of Motoko. FoundationDB and Antithesis were explicit inspirations. I wanted to exercise real implementation code under controlled conditions, explore failures, and be able to reproduce the execution that exposed a problem.

In Motoko, the production driver can run against a modeled environment. The test supplies controlled responses at the boundaries it covers: model interactions, tool outcomes, environmental observations, and time. Faults can occur in that environment, and the real recovery logic has to deal with them. The execution produces a structured record that can be inspected and replayed.

That makes questions about sequences tractable. What does the driver do after a tool times out? What state does it retain after compaction? Does a replay reproduce the recorded interactions and terminal outcome? A failing run can become something concrete to investigate and keep as evidence.

The tests also have boundaries. A structural check can establish that particular instructions survived without establishing that every sentence of a summary preserved its meaning. A tested recovery path says something about that path under the exercised conditions. It cannot certify arbitrary generated code. The [technical report](../papers/motoko-dst-report/DRAFT-3.md) goes into the architecture and those limits in much more detail.

For my original ambition, the value is practical. If I want less direct involvement in implementation, I need ways to check behavior that do not depend entirely on reading every change. DST supplies executable evidence for part of that trust. Building it also revealed how difficult it can be to decide that the evidence is sufficient.

Project 009 developed the broader deterministic test-world machinery. Its records contain an uncomfortable example of a process that could keep producing justified work without moving toward completion. This happened before Motoko's later herdr-based orchestration; it became part of the experience the factory needed to learn from.

Between July 26 and August 2, the [project retrospective](../.agent/projects/009_motoko_dst_execution/NOTE-review-loop-retrospective.md) counted 154 findings across 19 review sections, nine correction passes, and no source changes in the measured interval. The architecture was largely settled. The churn concerned the mechanisms for checking it, which were being specified in increasing detail inside an architecture decision record.

Each correction could leave behind the same obligation: the correction had not yet been independently verified. A further review could find real defects and create another correction pass. The usefulness of individual findings did not give the whole process a stopping condition.

Meanwhile, a concrete dependency needed work. Motoko had to display streamed model output immediately while retaining an exact ordered record for replay. The existing AILANG callback contract could not return the accumulated record in the form the design required. The [project's release and adoption record](../.agent/projects/009_motoko_dst_execution/HANDOFF-post-upstream-recorded-stream-landing.md) traces the requirement through a prototype, upstream work, a released recorded-stream API, and adoption in Motoko.

This was a particularly useful instance of the relationship with AILANG. The language's API constrained the agent's implementation; the agent's testing requirements supplied a reason and a concrete contribution to change that API. Progress depended on the two systems developing together. Another round of reviewing the architecture could not substitute for that work.

The implementation phase found a second way to expand indefinitely. Passing checks exposed cases where the claimed behavior had not actually been exercised. Each finding became another task. As the checks became better at revealing their own gaps, the finish line kept moving.

On August 9, the [plan](../.agent/projects/009_motoko_dst_execution/PLAN-implementation-deterministic-test-world.md) established a bounded outcome: demonstrate a real session with an effectful extension being recorded and replayed, and classify the extensions according to what the system mediated or explicitly disclosed as a limitation. New findings would block completion only if they blocked those outcomes. Other work would go to maintenance.

The [closing note](../.agent/projects/009_motoko_dst_execution/NOTE-d28-the-final-acceptance-rerun.md) is dated the same day. It still reported six findings, all assigned to maintenance, within a register containing 19 entries overall.

That episode changed the shape of the problem. A factory needs to detect defects, and it also needs a meaningful definition of completed work. Delegating implementation while leaving completion defined as “keep finding and fixing everything” creates an expanding queue. Choosing the outcome, the evidence required, and the place for remaining limitations is engineering work too.

The October 4 DST demonstration shows what some of that effort bought. Motoko ran a prescribed sequence against its own source: exercise a simulation corpus, introduce a specific one-line defect, inspect the results, and restore the source. The [run note and scorecard](motoko-dst-demo-run-2026-10-04.md) preserve the observed behavior.

The defect was small. An environment read returned a value and an updated world state containing the record of that read. The next operation was changed to continue from an older state. The read had happened, and its value was available, but its record was discarded.

The compiler accepted the change. The four-seed corpus passed. The recorded-program identities changed, showing changed behavior, but that alone could not say whether the change was desirable. Replay reproduced the incomplete recording and agreed on the terminal outcome.

Then a separate completeness assertion reported the missing observation:

```text
[discovery-env-read-under-recorded] this scenario's control flow reaches 1 read(s) of 'MOTOKO_RETRY_STREAM_ERROR' and the log records 0
```

The important results fit in a small table:

| Check | With the defect | After restoration |
|---|---|---|
| Type check and four-seed corpus | Pass | Pass |
| Recorded-program identities | Changed | Original identities returned |
| Replay agrees with the recording | Pass | Pass |
| Expected read is present in the recording | Fail | Pass |

The completeness assertion used an expectation derived from source and control flow. It was not an independent runtime counter of reads. Even within that boundary, it exposed something replay agreement alone could not: both executions could consistently lose the same observation. The defective recording contained 30 interactions; restoration brought it back to 31.

Both edits were scripted, and test subprocesses loaded the changed source. The running agent was conducting the procedure, with no delegation involved. This demonstrated Motoko operating its own development tools under supplied instructions. Byte-for-byte comparison confirmed restoration.

A bug can be perfectly reproducible. Confidence depends on asking a question capable of detecting it. That is one recurring lesson of this project: a report of success needs evidence that addresses the claim being made.

The current factory brings another set of responsibilities into view. Motoko coordinates development work; herdr provides delegation to agents such as Claude Code and Codex; dagr represents tasks, dependencies, acceptance criteria, and progress. DST supplies reproducible checks on the harness behavior it covers. I use this arrangement while developing Motoko, so the system participates in work on itself.

Using the factory exposes failures that a description of its components would miss. One particularly revealing incident is recorded in the [orchestrator implementation](../packages/motoko-ext-herdr/orchestrator.ail). On September 12, a session instructed to delegate made 10 delegation calls. On September 13, a session resumed from its handoff made zero delegations and 395 shell calls, carrying out implementation directly.

The handoff had preserved work state and warnings, but lost the instruction to act as an orchestrator. A responsibility that existed in a conversation turn disappeared across the session boundary. The resumed agent could continue working while quietly changing the division of labor.

The response was to represent the role persistently in the run state, add a standing role instruction, and reinforce it with tool policy. That gives later sessions something durable to recover. The policy has limits, but the incident supplied a concrete reason for moving an important instruction out of conversational memory.

This is an engineering question that extends beyond building agents: how should a factory preserve roles, plans, and evidence while its workers and sessions change? A plan can survive as text while its operational meaning is lost. A worker can finish a task while the coordinating system still has the wrong account of what happened.

Keeping delegation outcomes and the dagr graph synchronized remains current work. A completion message is one piece of information. Connecting it to the actual result and the relevant checks is another responsibility. The graph must be useful as a representation of the work being done, including the conditions under which an item can be considered complete.

The factory therefore needs continuity at several levels: the software's behavior, the plan, the roles of the participants, and the evidence supporting their decisions. These are places where the abstraction still demands attention. Making them reliable is part of moving from personally supervising implementation toward entrusting larger objectives to the system.

That brings me back to self-improvement and the question of what the factory should try next. The immediate work is stabilizing it. Two research directions help make the longer ambition more concrete.

The [comparative self-evolution research](../.agent/projects/014_comparative_self_evolution/RESEARCH-godel-machine-lineage-for-motoko.md) explores preserving alternative versions, their ancestry, and their task results. Recurring failures could suggest changes; comparisons between versions could reveal useful differences; experiments could branch from earlier versions. Its proposed starting point is modest: connect versions to outcomes and build an advisor that reports hypotheses before automating the decisions.

DST could support that process by rejecting some broken candidates before expensive benchmark evaluation. For failures reproducible in a simulated world, comparing executions could help locate where behavior diverges. That still leaves the question of whether a change improves performance. The proposal also separates changing the system from changing its evaluator: hold the evaluator fixed during an improvement round, then review changes to it separately. Otherwise a candidate could appear to improve by relaxing its own test.

The [idea factory](../.agent/projects/015_idea_factory/RESEARCH-idea-factory-and-idea-evaluation.md) asks the question at another level. The opening ambition assumes that I supply an idea. How much could the factory contribute to discovering and combining ideas, and choosing which deserve an experiment?

Its research considers matching recorded weaknesses with new capabilities, mapping outside concepts onto Motoko, and finding connections between existing ideas. A new language feature might answer a standing research question. Two proposals might turn out to address the same underlying problem. An unexpected direction might expose something the current tests cannot measure.

The work is exploratory. The idea-factory notes describe a manual research process and proposals for making it more explicit; automating generation and selection remains deferred. The comparative work likewise describes a possible route toward an improvement loop. Together they connect trying changes with learning what is worth trying.

That is why the road toward RSI has so much room for exploration. The factory can become better at carrying out an idea, checking an outcome, coordinating work, or helping formulate the next question. Each would change what I can spend my attention on.

I still want to build and experiment faster. Motoko gives me a system in which to pursue that ambition and encounter its practical limits. The broader Post-AI software engineering experiment is to discover how much of the journey from curiosity to a working system we can entrust to such a factory. How far can we take that—and what will we be able to explore when we get there?
