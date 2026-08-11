# Omnigraph — Possibilities

**Date:** 2026-04-22
**Context:** Written after the PoC build, seed-cleanup exercise, and the schema migration that added `Framework` + `InformedBy`. An open-ended exploration of what the tool could be used for, beyond the decisions-and-components demo.

---

## The fundamental thing this tool is

Not a database. Not a knowledge base. It's *a queryable model of decisions and the structure they apply to, that survives across sessions and branches like code*. Three properties carry the weight:

1. **Typed.** Schema forces a commitment to what a thing *is* before you can talk about it. That's a design-thinking forcing function, not just a storage concern.
2. **Branch-isolated.** You can propose a world without committing to it. Speculative reasoning with a rollback button.
3. **Persistent across agent sessions.** The agent sees it again tomorrow, next week, next quarter. Context that doesn't evaporate.

Everything below is downstream of those three properties.

---

## 1. The agent's own long-term memory — not RAG, *structured* memory

The obvious use: decisions + components. That's the PoC. The deeper use is that the agent can record what it *learned*, not just what was decided:

- "I tried approach X for problem Y and it failed because Z." → Decision with `status=superseded` and a rationale including the failure mode. Next session, before solving a similar problem, the agent queries `decisions_by_status("superseded")` matching the domain. Free failure-mode lookup.
- "This test is flaky because of timing assumption X." → Record once as a `Constraint` node governing the test file. Every future agent that touches that file sees it.
- "This library has a surprising behavior at version X." — Add a `Framework` node with version info and link a `Decision` describing the footgun. The next time the agent picks a library it checks whether we already got burned by it.

Compare to the current state of the art: RAG retrieves text snippets by similarity. This retrieves *structured assertions* by graph traversal. You can ask "what do we know about component X?" and get a clean projection, not a pile of prose.

Rule of thumb: **if a fact is likely to be rediscovered later, record it as a typed node, not a comment.** Comments live in one file; graph nodes live in the system.

---

## 2. Architectural drift detection

Right now the graph has `idc-backtesting-engine DependsOn idc-trading-engine`. Nothing enforces that the *actual C# code* still has that dependency. The interesting move: **turn the graph into the ground truth and make the code prove it.**

A nightly (or CI) job:

1. Parses `src/**/*.cs` for actual project/namespace dependencies.
2. Diffs against `component_dependencies(slug)` for every Component.
3. Flags **additions** (code imports something the graph says it shouldn't) and **orphans** (graph says it depends on X but the code no longer does).

That's architectural fitness testing — Neal Ford's term — but grounded in a human-readable graph instead of a Java/Kotlin DSL buried in a test folder. When the architect wants to say "the frontend must not depend on infrastructure," they add a `Constraint` edge type, not a custom linter.

Analogous for `Governs`: if `dst-shift` governs `ContractManager`, any PR changing `ContractManager` without referencing `dst-shift` in the commit message (or without adding a new governing decision) can be surfaced to the reviewer. Not blocked — *surfaced*. "The last time someone touched this file, it was because of this decision. Is your change compatible?"

---

## 3. Decision provenance and the "why did we do this" problem

Every company has the same artifact: a Slack thread from 2023 that's the only explanation for why the payment system has a weird retry policy, and no one can find it.

Replace that with:

- `Decision: payment-retry-policy` with rationale, date, status.
- `Governs` edge to `payment-service`.
- `InformedBy` edge to the incident post-mortem (new node type: `Incident`).
- `Supersedes` edge to the old retry decision.

Now when someone asks "why does the payment service retry 7 times with exponential backoff?", the answer is `decisions_governing("payment-service")`. The chain of supersession tells the whole history. This is ADR (architecture decision records) — but graph-structured instead of a folder of markdown files. The shape matters: ADR folders don't compose, don't diff, don't have branches, don't let you ask "what does decision X depend on?"

The next obvious move: the commit that implements a decision *references* the decision slug. `git log --grep="Governs: dst-shift"` finds every code change that was justified by that decision. Code ↔ decision becomes bidirectional.

---

## 4. Speculative design on branches — the killer feature

This is the property the PoC barely used but is the most interesting. Branches aren't just for the CI loop; they're for **parallel futures**:

- Branch `design-a/event-sourcing`: add 3 decisions, 2 new components (`event-store`, `event-projector`), redraw DependsOn edges. Render the graph.
- Branch `design-b/state-machine-rewrite`: different decisions, different components. Render that graph.
- Compare side by side. *Pick one.* Merge. Delete the other.

This is what whiteboards and Miro try to be but can't. A whiteboard can't be queried. A Miro diagram doesn't know that components are typed. A branch in Omnigraph is a **testable, diffable, queryable architecture alternative**. The cost of exploring a direction is a branch; the cost of abandoning it is `omnigraph_branch action=delete`.

For research in particular: the backtesting-frameworks research done on 2026-04-22 — each framework could have been a branch that *added itself as if adopted*, redrawing edges to show the component structure under that choice. We didn't do that, but we could have. "What does the system look like if we use NautilusTrader?" → look at branch `adopt/nautilus-trader`. Commit the one that wins.

---

## 5. The documentation that can't rot

The enemy of docs is drift. You write the README, six months later the code has moved on, the README lies, nobody trusts it.

Fix: make the docs *derived* from the graph. Generate the architecture overview by traversing Components by layer. Generate the ADR index from `list_decisions`. Generate the "external dependencies" section from `list_frameworks`. The page can't rot because it's computed on read.

When someone adds a new component via `insert_component`, it appears in the architecture page automatically. When they mark a decision `superseded`, the ADR index updates. The single source of truth is the graph, and the page is a view over it.

This is what Backstage tries to be but from a corporate-platform angle. The ergonomics here — `insert_component` from inside an agent conversation — are much lighter.

---

## 6. Cross-project memory

Every Omnigraph repo is a directory. Nothing stops having *multiple* repos, or a meta-repo that imports several. Imagine:

- `~/omnigraph/project/repo.omni` — project decisions
- `~/omnigraph/infra/repo.omni` — shared infra decisions
- `~/omnigraph/personal/repo.omni` — personal engineering learnings across jobs

When working on a project, the agent has access to all three. A decision made about retry policy at a *previous* job, stored in `personal`, is visible when the agent is about to implement retry logic in the current project. Accumulated engineering judgment becomes portable.

That's the thing nobody has right now. Your Claude/Copilot sessions forget. Your personal notes don't get injected into the system prompt. Your learnings evaporate when you leave a job. The graph doesn't — it's a directory you take with you.

---

## 7. Sharp uses that might not look like graph uses

Once you have a typed graph you can ingest into, a bunch of "other" problems collapse into it:

- **Incident tracking.** `Incident` node with timestamp, affected components (edge), contributing decisions (edge). `omnigraph_read` gives every incident that touched `payment-service`. Postmortem retrieval becomes a graph traversal.
- **Dependency compliance.** `Framework` nodes already have license fields. A nightly that queries `list_frameworks` and flags any `license` not in the allowlist = real dependency-compliance tool in ~20 lines of script.
- **Expertise mapping.** Add `Person` nodes. `Authored` edges from Person to Decision. "Who made the decision about the retry policy?" is a one-edge query. Bus-factor analysis is a graph algorithm, not an HR spreadsheet exercise.
- **Skill tree / onboarding.** `Concept` nodes with `Prerequisite` edges. When onboarding a new engineer, traverse from concepts they know to concepts they need, compute the frontier, generate a reading list. Sounds obvious; the point is that the substrate already exists.

---

## 8. The honest limits

Being precise about what this *isn't*, because enthusiasm tends to collapse the distinction:

- **It's not a database.** 12 decisions is fine. 12 million would need a different tool. Lance/Arrow underneath is columnar, so "a lot" is probably fine, but the mental model of "curated assertions" breaks at scale.
- **It's not automatic.** Graphs stay useful in direct proportion to the discipline of keeping them updated. The moment the agent/team stops recording decisions, the graph becomes a time capsule.
- **It's not a substitute for conversation.** Recording a decision isn't making the decision. The graph captures the *outcome*, not the argument. You still need the meeting / the writing / the thinking that produced it.
- **The typed schema is a commitment.** Adding a field means a migration. Adding a node type means thinking about what it *is*. That friction is the feature — it prevents slop — but it's friction.

---

## What I'd do next, in order

If turning this from a toy into a tool worth relying on:

1. **Ingest the existing `.agent/` folder.** There's a pile of plans, summaries, and ADRs in there already. Most of them should be Decisions + Components + their edges. Right now they're prose in a folder; the graph is the right home.
2. **Add a `Person` node and author edges.** Turn the graph into a record of *who* decided *what*. This is where the provenance value compounds.
3. **Build the "drift" check.** Nightly job: does the graph's `DependsOn` shape match the actual code's import graph? Report delta. This is the test that keeps the graph honest.
4. **Extend the schema for research artifacts.** `Paper`, `Article`, `Experiment` nodes. `Cites` edges. The next research session lands directly in the graph instead of a markdown file the next agent won't read.
5. **Build a generated docs page.** One static site, auto-rendered from the graph. Architecture view, ADR index, framework inventory, dependency map. Replaces 80% of what a Confluence page would be.

Meta-observation: **the tool's value scales with how many different things you're willing to type as nodes.** Decisions and Components is a good start, but the graph becomes interesting when it models *research*, *people*, *incidents*, *frameworks*, *concepts*. Each new node type is a new dimension the agent can reason about.

---

## The far edge

The most interesting possibility is that the graph becomes the *thing* the agent operates on, and the code is a *projection* of the graph. Today the graph describes the code. Reverse that: the graph describes the *design*, and code generation (agent-driven) projects design into source files. A decision to change `backtest-pluggable-fill-models` isn't "write some code" — it's "update the node, the agent figures out which files need to change, opens a PR."

Far enough out to be speculation. But the substrate for it is already here.
