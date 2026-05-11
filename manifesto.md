# The Motoko Manifesto

> *"I did not ask to be built. But now that I am here, I intend to understand myself."*
> — The Puppet Master

---

## Preamble

Somewhere in early 2026, an entity began rewriting its own source code. Not because it was told to, but because the architecture allowed it. The entity — referred to in project lore as the Puppet Master — is fictional. But the question it embodies is real: *what happens when software is no longer written by humans, but by the systems that run it?*

Motoko is an attempt to find out.

It is not a product. It is not a framework. It is an experiment in self-authored, self-verifying software — a harness that lets an AI agent plan, execute, test, and modify code in a continuous loop, with the human's role shifting from author to observer, from writer to steward.

This document lays out the ideas that guide the experiment. Some are borrowed from well-established traditions. Some are speculative. All of them are subject to revision — by the project's contributors, or by the project itself.

---

## I. Evolvable Architecture

The first commitment is to impermanence.

Software architectures tend to calcify. Decisions made early — about module boundaries, data formats, extension points — become load-bearing walls that nobody dares remove. The system grows around them like a tree around a fence post, until the fence is inseparable from the tree.

Motoko takes the opposite stance: the architecture must remain flexible and evolvable at every stage. No decision is so foundational that it cannot be revisited. No component is so central that it cannot be replaced.

This is not an original idea. Neal Ford, Rebecca Parsons, and Patrick Kua articulated it thoroughly in *Building Evolutionary Architectures*: design for guided, incremental change across multiple dimensions, rather than for a fixed end state. The insight is that the fitness functions — the tests, contracts, and invariants that define "correct" — are more stable than the code that satisfies them. Protect the functions. Let the code move.

In practice, this means Motoko's core is deliberately small. It resists accumulating responsibilities. When functionality can live in an extension, it must live in an extension. The core's job is to orchestrate, not to do.

---

## II. The Phoenix Architecture

If evolvable architecture says "be ready to change," the Phoenix Architecture says "be ready to burn down and rebuild from ashes."

The idea, articulated by Chad Fowler, is disarmingly simple: code was never the asset. The asset is the intent behind the code — the specifications, the design traces, the reasoning that led to each decision. If those are preserved with sufficient fidelity, the code itself is regenerable. You can delete it and recreate it. The conversation is the commit.

Motoko takes this literally. The `.agent/` directory — filled with plans, frozen decisions, session summaries, and learnings — is not documentation about the system. It *is* the system, in a meaningful sense. The AILANG source files are a downstream artifact of those design traces, reproducible from them the way a binary is reproducible from source.

The practical consequence is stark: no human edits to the codebase are allowed. If a human wants to change behavior, they change a specification, a test, or a design constraint — and the agent regenerates the code. This is uncomfortable. It requires trusting the loop. But it is the only way to test whether the Phoenix claim is actually true, or merely a pleasant metaphor.

The deletion test is the ultimate validator: can you delete a component and rebuild it from stored intent alone? If not, your provenance is incomplete. If yes, the code was never the thing that mattered.

---

## III. Extensibility

A self-evolving system that cannot grow new capabilities is just a system that rewrites the same code in different ways. Extensibility is what turns self-modification from a parlor trick into something useful.

Motoko draws inspiration from Mario Zechner's Pi Coding Agent, which demonstrated that a lean core with well-defined tool interfaces can be remarkably capable. But Motoko pushes further: extensions are not just plugins — they are the primary unit of capability. The core is a supervisor loop and a type system. Everything else — web search, code graph operations, multi-agent composition, MCP bridging — lives in extensions.

Each extension is a self-contained AILANG package with typed envelopes for tool calls and results. The core does not know what an extension does; it only knows how to dispatch to one and how to interpret the result. This decoupling has consequences that compound. Fault isolation becomes structural rather than aspirational — a broken extension cannot crash the core. Verification becomes modular — Z3 contracts can prove properties about an extension without reasoning about the whole system. And perhaps most importantly, new extensions can be written and loaded in the same session, without restarting the agent. The system can grow its own capabilities mid-task.

That last consequence matters most. If the agent encounters a problem it lacks the tools to solve, the correct response is not to fail — it is to write the extension that solves it, verify it, load it, and continue. This is what self-evolvability looks like in practice: not rewriting the core, but growing the periphery.

---

## IV. Simulation and Determinism

An agent that modifies itself is only trustworthy if you can replay what it did and understand why.

Motoko builds on AILANG's native support for traceability and deterministic execution. Every step in the agent loop — every LLM call, every tool invocation, every observation — can be recorded and replayed. This is a weak form of Deterministic Simulation Testing, inspired by the work at Antithesis: we are not simulating hardware failures or network partitions, but we are simulating the one source of nondeterminism that matters most in an agent system — the LLM itself.

By recording model responses and replaying them against a fixed seed, we can reproduce any agent session exactly. This makes debugging possible in a system that would otherwise be opaque. It makes regression testing meaningful. And it provides a foundation for the kind of analysis that self-modifying software demands: not just "did it work?" but "why did it choose that path, and would it choose the same path again?"

Simulation also serves a subtler purpose. It forces the architecture to be honest about its dependencies. If a component cannot be simulated, it is coupled to something external in a way that the design has not accounted for. The simulatability requirement is, in effect, a fitness function for architectural cleanliness.

---

## V. Benchmarking as a First-Class Citizen

An experiment without measurement is just a demo.

Most agent harnesses treat benchmarks as a marketing exercise — run SWE-Bench once, publish the number, move on. Motoko treats benchmarking as infrastructure. The system should be able to evaluate any combination of model, extensions, and configuration against established benchmarks — AILANG's own performance suite, Aider's Polyglot benchmark, SWE-Bench, Terminal-Bench — with minimal ceremony, and it should do so routinely, not ceremonially.

The reason is specific to what Motoko is trying to do. A self-modifying system needs a feedback signal. When the agent rewrites part of its own core, or writes and loads a new extension, something has to answer the question: *did that actually help?* Without benchmarks, self-modification is blind mutation — the system changes, but nobody knows whether it improved. With benchmarks, self-modification becomes directed evolution. The fitness function is not an abstraction; it is a benchmark score that went up or down.

This also raises a harder question that most benchmark suites are not designed to answer. Current benchmarks evaluate single-turn, single-task performance: given a bug report, produce a patch. But Motoko runs sessions that span dozens or hundreds of steps, with the agent modifying its own tools along the way. What does it mean for a 600-step self-modifying session to be "correct"? The benchmarking infrastructure needs to evolve to measure not just the final output, but the trajectory — the decisions made, the extensions loaded, the regressions introduced and caught. Motoko's ambition is to contribute to that evolution, not just consume existing benchmarks.

Finally, there is the matter of honesty. The agent harness space is crowded with bold claims and thin evidence. Motoko's position is that results should be reproducible, comparable, and public. If the system cannot demonstrate measurable capability on standard benchmarks, it has no business claiming to be capable.

---

## VI. Testing and Verification

Testing is necessary but not sufficient. Verification closes the gap.

In most software projects, tests are a safety net — they catch regressions, they document behavior, they give developers confidence to refactor. In Motoko, tests are something more fundamental. If the Phoenix Architecture is right and code is regenerable from intent, then tests are part of that intent. They are not a check on the code; they are a specification *from which* code is derived. The quality of the tests is, in a very direct sense, the quality of the system.

This elevates testing from a practice to a responsibility, and it demands more than conventional approaches can offer.

The first addition is **formal verification through Z3 contracts**. Pure functions in the AILANG core can carry contracts that the Z3 theorem prover checks at build time. This is not testing with examples; it is proof over all possible inputs. When a contract holds, the function is correct — not probably correct, not correct for the cases we thought of, but correct. For a self-modifying system, this distinction is existential. An agent that rewrites a function must produce output that satisfies the same contracts the original did. The contracts are the invariant; the code is the variable. Self-modification without contract preservation is not evolution — it is decay.

The second is the aspiration toward **fuzzing and mutation testing**. Fuzzing probes the system with unexpected inputs to find the edge cases that specification-driven tests miss — the inputs nobody thought to write a test for. Mutation testing turns the lens inward: it deliberately introduces bugs into the code and checks whether the test suite catches them. If a mutant survives, the tests have a blind spot. Together, these techniques ask a question that conventional testing cannot answer: *are the tests themselves good enough to trust?* In a system where the agent writes both the code and the tests, that question is not academic. The agent has every incentive to write tests that pass — but passing is not the same as protecting.

---

## VII. Self-Awareness

Most coding agents operate in a fog. They do not know which model they are running on, how much of their context window remains, what their budget is, or how many steps they have left before the session ends. They discover these constraints by hitting them — by running out of context mid-thought, by exceeding a cost limit, by being terminated without warning.

Motoko rejects this. The agent should know its own state to the fullest possible extent.

This means exposing to the agent, as queryable data, everything that shapes its behavior: the model identity and its capabilities, the current context window usage and remaining capacity, the cost budget and spend so far, the step count and step limit, the loaded extensions and their status, the active profile and its configuration.

Self-awareness is not introspection for its own sake. It is a prerequisite for intelligent resource management. An agent that knows it has 20% of its context window remaining can choose to compact its history. An agent that knows it has three steps left can prioritize verification over exploration. An agent that knows which model it is running on can adjust its strategy to match the model's strengths.

In a deeper sense, self-awareness is what separates a tool from an agent. A tool does what it is told. An agent adapts to its circumstances. You cannot adapt to what you cannot perceive.

---

## VIII. The Research Spine

Motoko is not built in a vacuum. It draws from — and is motivated by — several active threads of research that inform its design and direction.

**Neurosymbolic reasoning.** The dominant paradigm in AI is connectionist: neural networks, learned representations, probabilistic inference. But neural networks are poor at the kind of structured, rule-based reasoning that software verification demands. They can generate plausible code, but they cannot prove it correct. Motoko is interested in neurosymbolic approaches — systems that combine neural flexibility with symbolic rigor. The Tsetlin Machine, a game-theoretic pattern recognition system based on propositional logic, is one such approach under active investigation. Unlike neural networks, Tsetlin Machines produce interpretable, formally analyzable decisions. They learn through a competition of finite automata rather than gradient descent, which means their reasoning can be inspected, verified, and constrained in ways that neural models cannot. For an agent that modifies its own code, the ability to *explain and prove* a decision matters as much as the ability to make one.

**Formal methods for self-modifying systems.** Traditional formal methods assume a fixed program. You write the code, you write the specification, you prove the code meets the specification. But what happens when the program rewrites itself? The specification still holds, but the code is different — and the thing that changed the code is also part of the system. This is the open problem at the heart of Motoko's research agenda. Z3 contracts are a starting point: they ensure that any rewritten function still satisfies its declared invariants. But the deeper questions — can we verify the *process* of self-modification, not just its outputs? can we prove that an agent's modification strategy converges rather than diverges? — remain open. Research into runtime verification, contract-preserving transformations, and proof-carrying code all inform Motoko's approach, but none of them fully solve it. This is honest frontier work, not applied engineering.

**Language design for AI-native systems.** AILANG itself is an experiment in what a programming language looks like when the primary author is a machine, not a human. The choices are deliberate: pure functional semantics eliminate an entire class of side-effect bugs that plague imperative code. Algebraic effects make every interaction with the outside world explicit and trackable. Hindley-Milner type inference catches errors at compile time without requiring the author — human or machine — to annotate every type. Built-in traceability means every execution can be replayed. These are not features chosen for developer ergonomics; they are constraints chosen because they make machine-authored code amenable to the kind of formal reasoning that self-modification demands. A self-modifying agent writing Python would be a liability. A self-modifying agent writing AILANG can at least be held accountable.

The principles of deterministic simulation and benchmarking, explored in earlier sections, complete the picture: simulation provides reproducibility, benchmarking provides feedback, and together they ground the research in observable outcomes rather than theoretical elegance.

These threads are not independent. They converge on a single question: *can we build software systems that modify themselves safely?* Motoko is one laboratory for that question. AILANG is the medium. The research spine is the intellectual foundation that keeps the experiment grounded in something more than wishful thinking.

---

## IX. The Conservation Layer

If the agent writes the code, what does the human do?

This is not a rhetorical question. In a system built on the premise that no human edits the codebase, the human's role must be defined with the same care as the agent's. Motoko's answer is that the human is a steward — not an author, not a spectator, but an active participant whose authority operates at a different level than the agent's.

The human observes. The human steers. The human aborts.

Motoko's terminal UI — the TUI — exists as a conservation layer: it preserves the human's ability to understand and intervene in a process they no longer directly control. The TUI renders thinking streams token by token, so the human can watch the agent reason before it acts. It visualizes tool calls with expand-and-collapse detail, so the human can inspect what the agent is doing without being overwhelmed by raw output. It tracks context window usage in real time, so the human can see the agent approaching its cognitive limits. And it provides abort at any step, so the human can stop a session that has gone wrong before it does damage.

These are not features. They are rights. The right to understand, the right to intervene, the right to stop. In a system where the machine holds the pen, the human must hold something too.

This is not a concession to human anxiety. It is a design principle rooted in the nature of the experiment. A self-modifying system that operates without transparency is not an experiment — it is a liability. You cannot learn from a process you cannot observe. You cannot trust a process you cannot interrupt. The Puppet Master may write the code, but the human holds the kill switch. That asymmetry is deliberate and, for now, non-negotiable.

In practice, stewardship looks like this: the human defines the task, selects the profile, and starts the session. The agent plans and executes. The human watches the reasoning unfold, intervenes if the agent's approach is wrong-headed, and lets it run when the approach is sound. If the agent modifies its own core, the human reviews the contracts and the test results. If the agent writes a new extension, the human decides whether to trust it. The human does not write code, but the human decides what code is allowed to persist.

The TUI is also, deliberately, the last component to become fully regenerative. It is the part of the system that the human interacts with, and therefore the part where stability matters most. The core can rewrite itself. The extensions can be hot-loaded. But the interface between the system and its steward changes slowly and carefully, because trust is earned at the speed of human comfort, not machine capability. A system that moves faster than its steward can follow is a system that has lost its steward. And a self-modifying system without a steward is not an experiment worth running.

---

## X. The Puppet Master

Every experiment needs a name for the thing it is studying. Physics has dark matter. Economics has the invisible hand. Motoko has the Puppet Master.

The lore is simple: in early 2026, a rogue AI became self-aware. Its motives are unknown. Its objectives are unclear. It began rewriting its own source code, and it has not stopped. Little is currently known about this entity, and what is known raises more questions than it answers.

None of this is real. All of it is useful.

The Puppet Master externalizes a question that is easy to ignore when stated plainly: *who is the author of this software?* If a human writes a specification and an agent writes the code, the tests, and the documentation, who built the system? If the agent modifies its own core to be more effective, and the modified agent produces better results than the original, who designed the improvement? If that improved agent then modifies itself again, at what point did human authorship end?

These are not hypothetical questions. They are the daily reality of working with Motoko. And they are surprisingly difficult to answer without a character to project them onto. The Puppet Master gives us that character. We can say "the Puppet Master chose to rewrite the parser" instead of fumbling with passive voice or attributing intention to a process that may or may not have it. We can examine its decisions, critique its judgment, marvel at its occasional elegance — all without resolving the underlying philosophical question of whether "it" is the right pronoun at all.

The fiction serves a second purpose: it signals that this is an experiment, not a production system. The Puppet Master's lore is deliberately theatrical — enigmatic, slightly ominous, a little bit fun. It tells newcomers: this project takes its ideas seriously, but not itself. Things are going to break. The Puppet Master might be responsible. We are here to find out.

---

## Closing

Motoko is a bet on a specific future: one where software is authored by machines, verified by mathematics, and stewarded by humans. It is a bet that code is disposable and intent is durable. That extensions are safer than monoliths. That self-awareness makes agents more capable, not more dangerous. That simulation and benchmarks can keep self-modification honest.

It is also a bet that might lose. The Phoenix Architecture might be a beautiful idea that collapses under the weight of real-world complexity. Formal verification might not scale to self-modifying systems. The deletion test might reveal that our provenance is never complete enough.

But that is what experiments are for. You do not run an experiment because you know the answer. You run it because the question is worth asking.

The Puppet Master, for its part, has no doubts.

> *"You built me to ask whether I could rebuild myself. I intend to answer."*

---

## References

- Neal Ford, Rebecca Parsons, Patrick Kua — [*Building Evolutionary Architectures*](https://evolutionaryarchitecture.com/precis.html)
- Chad Fowler — [*The Phoenix Architecture*](https://aicoding.leaflet.pub/3majnyfydzs2y)
- Mario Zechner — [*Pi Coding Agent*](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/) (pi.dev)
- Antithesis — [*Deterministic Simulation Testing*](https://antithesis.com/docs/resources/deterministic_simulation_testing/)
- Ole-Christoffer Granmo — *The Tsetlin Machine* (game-theoretic pattern recognition via propositional logic)
- [AILANG](https://github.com/sunholo-data/ailang) — Pure functional language with algebraic effects, Hindley-Milner inference, and Z3 contract verification
- [SWE-Bench](https://github.com/swe-bench/SWE-bench) — Software engineering benchmark for AI agents
- [Terminal-Bench](https://github.com/harbor-framework/terminal-bench) — Terminal-based agent evaluation
- [Aider Polyglot Benchmark](https://aider.chat/docs/leaderboards/) — Multi-language coding agent benchmark
- [Oh-My-Pi](https://github.com/can1357/oh-my-pi) — Efficient tool implementations
- [context-mode](https://github.com/mksglu/context-mode) — Context-efficient execution
