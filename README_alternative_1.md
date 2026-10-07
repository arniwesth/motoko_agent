# Motoko

Motoko is an experimental coding-agent harness built to make runtime failures reproducible. Its deterministic simulation tests run the production session driver inside a controlled world of model replies, tool results, faults and virtual time. A failing execution can be recorded, replayed and kept as a regression case.

The larger experiment is an agent that can help improve its own implementation. Motoko is written in [AILANG](https://github.com/sunholo-data/ailang), and coding agents write its code, including Motoko itself. The project follows [The Phoenix Architecture](https://aicoding.leaflet.pub/), with its rule against human-written code. That makes the test machinery central to the project: changes need evidence that can be inspected and reproduced.

<p align="center"><img src="assets/motoko.png" alt="Motoko" /></p>

*Project lore attributes the work to the Puppet Master, a rogue AI that became self-aware in early 2026.*

## Contents

- [Testing the software around the model](#testing-the-software-around-the-model)
- [Checking the checks](#checking-the-checks)
- [An architecture that supports the experiment](#an-architecture-that-supports-the-experiment)
- [Agents building their own tools](#agents-building-their-own-tools)
- [Try Motoko](#try-motoko)
- [Extensions](#extensions)
- [Working on the project](#working-on-the-project)
- [Scope and open work](#scope-and-open-work)
- [Acknowledgements](#acknowledgements)

## Testing the software around the model

A tool finishes after its deadline. A provider fails halfway through a turn. History is compacted while a delegated task is still running. Each event leaves the harness with obligations: account for the attempt, keep the right messages, preserve pending work and decide what happens next.

Motoko uses deterministic simulation testing to exercise those obligations. The core accesses its environment through explicit ports for model calls, tools, files, settings, approvals, time and wake-ups. In normal operation, those ports reach live services. In a simulation, they serve responses from a seeded world. Both paths run the same session driver.

The simulator controls what happens at those boundaries, including failures and delays. Recording adapters capture the interactions for replay. Checks over the execution trace then look for properties such as correctly paired tool calls and results, consistent budgets, valid state transitions and recoverable session history. Virtual time lets tests explore deadlines without waiting for the corresponding wall-clock interval.

Once the toolchain is installed:

```bash
make corpus_pr   # Fixed seeds and saved regression cases used in PR checks
make dst         # Full deterministic simulation sweep
```

The [CI workflow](.github/workflows/dst-corpora.yml) runs the PR corpus for pull requests and searches a changing seed window on a nightly schedule. The approach draws on the simulation testing work of [FoundationDB](https://www.foundationdb.org/files/fdb-paper.pdf) and [Antithesis](https://antithesis.com/docs/resources/deterministic_simulation_testing/).

For the architecture and evidence, start with the [DST technical report](papers/motoko-dst-report/DRAFT-current.md).

## Checking the checks

Replaying a recording successfully can reproduce a bug just as faithfully as correct behavior. Motoko has a demonstration of this: it deliberately changes one line in its own driver so that an environment read disappears from the recording. The code still type-checks, and replay still agrees with the incomplete record. A separate completeness check catches the missing read.

```bash
make build
make demo_dst
```

The demo uses a live model to make the edit, run the checks, explain the results and restore the source. It needs a provider API key and a clean `src/core/session.ail`; run one demo at a time because it edits that file and uses a shared temporary directory. The [recorded demonstration](docs/motoko-dst-demo-run-2026-10-04.md) includes the mutation, observed results and diagnostic.

The same concern shapes the rest of the testing:

| Evidence | What it contributes |
|---|---|
| Versioned execution profiles | State which extensions and capabilities a simulation covers, along with its exclusions. |
| Invariant accounting | Reports whether a check actually evaluated relevant input, making empty passes visible. |
| Recording completeness checks | Compare recorded interactions with expectations derived from the source and scenario. |
| Negative controls | Introduce known violations to demonstrate that a check can reject them. |
| Z3 contracts | Prove stated properties of selected pure functions; classification identifies contracts that hold trivially. |

These checks support different claims. Their reports are part of the result, alongside the pass or fail verdict.

## An architecture that supports the experiment

AILANG makes effects part of function signatures. A pure prompt-shaping hook cannot read a file; a hook permitted filesystem effects does not thereby gain permission to launch a process. Tests can also withhold runtime capabilities to expose attempts to bypass a simulated port.

The core separates its [pure decision policy](src/core/step_machine.ail) from the [session driver](src/core/session.ail) that carries out those decisions. Each environmental interaction returns an updated world explicitly, giving the simulator a record of how the execution advances.

Session state also has a life beyond a single process. The TypeScript host writes a durable journal, and resume reconstructs state after checking the journal's digest chain and tool-call pairing. Simulation checks compare reconstructed state with the state reached by the driver.

Waiting is represented in the runtime. When a delegate is working, a session can park and wake on a result, operator input or a timer. The park is journaled so that a resumed session can recover its waiting state.

These choices make long-running work inspectable: what the driver observed, how it changed state and what a later process can recover.

## Agents building their own tools

Motoko can delegate work to `claude`, `codex` and `omp` agents in [herdr](https://herdr.dev) panes, with task dependencies tracked in a dagr graph. In orchestrator mode, the coordinating agent routes work and verifies results. A tool policy restricts its implementation edits, and its role is stored in the run file so that it survives handoffs.

The development record lives with the code. [Design projects](.agent/projects/) contain decisions, plans, reviews and handoffs. The [PR tooling](tools/pr/README.md) requires predicted outcomes and test evidence before publishing a pull request, and [PR records](.agent/github/prs/) preserve that account of a change.

Recursive self-improvement is the research goal. The current work is establishing the engineering conditions for it: persistent state, explicit responsibilities, reproducible failures and useful checks on agent-written changes.

## Try Motoko

From a checkout on Debian, Ubuntu or macOS:

```bash
./scripts/install-prerequisites.sh
export OPENROUTER_API_KEY=sk-or-...
make run
```

The installer sets up the toolchain, and `make run` builds Motoko and opens the terminal UI. The default profile uses OpenRouter. Provider keys can also go in a gitignored `.env` file in the repository root.

Start with a task or select a configuration profile:

```bash
make run TASK="Add tests for the parser"
PROFILE=openrouter make run
```

Inside the TUI, `/model` and `/profile` open selectors, and `/abort` stops the runtime. For a scripted task:

```bash
./scripts/run-agent.sh --headless "Add tests for the parser"
```

For unattended work, use the [agent sandbox](.devcontainer/agent_sandbox/README.md). It runs Motoko and its delegates in a container with restricted network access, a GitHub bot identity, and no `sudo`, SSH client or Docker socket. Its checkout is shared with the host, so edits inside the container still change files on the host. A [VS Code dev container](.devcontainer/README.md) is also available for interactive development.

| Guide | Contents |
|---|---|
| [Running Motoko](docs/running.md) | Container setup, native installation and everyday commands |
| [Configuration](docs/configuration.md) | Profiles, provider routing and model selection |
| [Writing an extension](docs/extensions.md) | Package registration, configuration and build steps |

## Extensions

Extensions are AILANG packages selected through `extensions.order` in a profile's `config.json`. Their [typed interface](packages/motoko-ext-abi/types.ail) defines the hooks and effects available to them, and a [conformance suite](packages/motoko_ext_conformance/) checks the extension contract.

The default profile combines context-efficient execution, Exa search, persistent scratchpad cells, conversation compaction, guards against empty or repetitive responses, and herdr delegation. Exa search needs an `EXA_API_KEY`; herdr delegation needs a herdr pane.

Other packages add MCP tools, delegation through agent CLIs or A2A endpoints, code-graph operations, retrieval, AILANG-aware editing and on-demand skills. The `compose` extension explores multi-agent composition and remains partly non-functional. Browse the [packages](packages/) and [profiles](.motoko/config/) for the available combinations.

## Working on the project

```bash
make build              # Sync packages, check the core and build the TUI
make check_core         # Type-check the core and probe configured extensions
make test               # Core runtime tests
make test_integration   # Integration tests
make verify_core        # Z3 contract verification and classification
make dst                # Full simulation sweep
```

Run the TypeScript frontend tests with `cd src/tui && bun run test`.

| Location | Start here for |
|---|---|
| [src/core/](src/core/) | Session execution, tools, journals and simulation machinery |
| [src/tui/](src/tui/) | Terminal UI, host process and journal writer |
| [src/eval/](src/eval/) | Evaluation using recorded session data |
| [packages/](packages/) | Extensions, their interface and conformance checks |
| [scripts/](scripts/) and [tools/](tools/) | Installation, verification and development tooling |
| [papers/](papers/) | Research background and the DST report |
| [.agent/](.agent/) | The project's design and development history |

Bug reports, experiments and contributions are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) explains the workflow and where to report issues in Motoko or the underlying AILANG toolchain. For a runtime failure, a reproducible sequence and its observed behavior are especially useful.

## Scope and open work

Motoko is a research project. Its strongest evidence concerns the behavior of the AILANG session driver under specified observations and execution profiles.

The TypeScript host has separate tests and sits outside the core simulation. Extension coverage depends on the selected profile. Z3 contracts cover a limited part of the pure core. Orchestrator policy constrains ordinary tool use; process isolation comes from the container environment.

Simulation can check whether the harness handles a tool failure, preserves required context or reconstructs session state. Model judgment and successful completion of real tasks still need live evaluation. The [technical report](papers/motoko-dst-report/DRAFT-current.md) documents these boundaries and the work still in progress.

## Acknowledgements

Motoko draws on [FoundationDB](https://www.foundationdb.org/files/fdb-paper.pdf) and [Antithesis](https://antithesis.com/docs/resources/deterministic_simulation_testing/) for deterministic simulation testing, [Pi Coding Agent](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/) for extension design, [Oh-My-Pi](https://github.com/can1357/oh-my-pi) for tool design, [context-mode](https://github.com/mksglu/context-mode) for context-efficient execution, and [little-coder](https://github.com/itayinbarr/little-coder) for the benchmark harness.
