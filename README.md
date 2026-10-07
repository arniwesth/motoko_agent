<p align="center">
  <img src="assets/motoko.png" alt="Motoko" width="640">
</p>

# Motoko: Agent Harness with Native Deterministic Simulation Testing

[![DST corpora](https://github.com/arniwesth/motoko_agent/actions/workflows/dst-corpora.yml/badge.svg)](https://github.com/arniwesth/motoko_agent/actions/workflows/dst-corpora.yml)
[![verify-extensions](https://github.com/arniwesth/motoko_agent/actions/workflows/verify-extensions.yml/badge.svg)](https://github.com/arniwesth/motoko_agent/actions/workflows/verify-extensions.yml)

> **Agent-written.** Motoko's code is written by coding agents, Motoko among them, and its own runtime is the principal system under test. The badges above are the live results of the simulation corpus and of the core type-check and test gates.

Motoko is an experimental coding-agent harness written in [AILANG](https://github.com/sunholo-data/ailang). Its production session driver runs against a **deterministic test world**, so failures in state management and control flow can be reproduced, replayed and checked. The approach draws on **[FoundationDB](https://www.foundationdb.org/files/fdb-paper.pdf)** and **[Antithesis](https://antithesis.com/docs/resources/deterministic_simulation_testing/)**.

Deterministic simulation testing is a bet on **recursive self-improvement** (RSI), the project's destination: a system that rewrites its own harness needs evidence that each change left it working, without a person reading the code.

Motoko is also an experiment in modern, post-AI software development. It follows **[The Phoenix Architecture](https://aicoding.leaflet.pub/)** by Chad Fowler: no human-written code is allowed. Agents write the code, people work on ideas, decisions and evidence, and the rigor sits in the evaluations that judge each change.

**[Running Motoko](docs/running.md)** | **[Configuration](docs/configuration.md)** | **[Extensions](docs/extensions.md)** | **[DST Report](papers/motoko-dst-report/DRAFT-current.md)** | **[Design Archive](.agent/projects/)**

---

## Quick Start

On Debian, Ubuntu or macOS:

```bash
./scripts/install-prerequisites.sh
export OPENROUTER_API_KEY=sk-or-...
make run
```

The default profile uses an OpenRouter model, so one key is enough. To let agents work unattended, use the [agent sandbox](docs/running.md#agent-sandbox). For complete setup instructions, see [Running Motoko](docs/running.md).

### Run the Simulation Tests

```bash
make sync_packages
make corpus_pr       # Fixed seeds and promoted regression programs
make corpus_judge    # Invariants, additional checks and their negative controls
make strict_replay   # Replay, witnesses and recording completeness
```

These use simulated provider responses and need no API key. `make dst` runs the full sweep.

### Watch It Catch a Bug

```bash
make build
make demo_dst   # Needs an API key: a live model drives the demo
```

Motoko plants a mutant in its own driver: a scripted one-line edit that makes the driver lose the record of one environment variable it read. It then runs its checks on the broken code:

| Check | Result on the broken driver |
|---|---|
| Type check | Passes |
| Seeded corpus | Passes |
| Replay of the recorded run | Passes |
| `make strict_replay` | **Fails**, and names the missing read |

Replay passes because it compares the mutant with itself: the recording and the replay lose the same read. `make strict_replay` also holds the recording against a count that does not come from the recorder: the number of environment reads the driver's source says this scenario makes. That count is one and the recording has none, so the check fails and names the variable.

Motoko then restores the file byte for byte. The [run note](docs/motoko-dst-demo-run-2026-10-04.md) records one such run.

---

## Key Features

- **Deterministic simulation** - The production driver runs against a seeded world of model replies, tool results, approvals and virtual time
- **Fault injection** - Modeled provider errors, tool failures, correlation mismatches, approval denials and deadlines
- **Record and replay** - Recording ports turn a run into an execution program that replay serves again and checks
- **Trace invariants** - 13 families, including tool pairing, budget accounting and journal fold; each reports whether it ran and on how much input
- **Mutation testing** - Source mutants and negative controls show that each check can fail, and which defects no check sees
- **SMT contracts** - Z3-verified contracts on pure core functions, classified as substantive, tautology or spec-equals-body
- **Effect-typed extensions** - A hook's signature states the effects it may perform, and a run can withhold a capability
- **Durable sessions** - A session journal, checked reconstruction on resume, and park/wake for external waits
- **Agent-written** - Developed by coding agents, with delegation through [herdr](https://herdr.dev) and an [agent sandbox](.devcontainer/agent_sandbox/README.md)

Learn more: [DST technical report](papers/motoko-dst-report/DRAFT-current.md) | [Demo run](docs/motoko-dst-demo-run-2026-10-04.md) | [Scope notes](papers/motoko-dst-report/SCOPE-current.md) | [Design archive](.agent/projects/)

---

## Deterministic Simulation Testing

Motoko's core reaches the model, tools, files, environment, clock and approvals only through ports. Each port takes an explicit `WorldState` and returns its successor. A test swaps the live ports for a simulated world and runs the same production driver:

1. **Generate** - A seeded generator answers each request the driver makes and injects faults: provider errors, tools that fail, answer late or answer the wrong call, and denied approvals. Time is virtual
2. **Record** - Recording ports capture every interaction as an execution program
3. **Replay** - The driver runs again against that program. Replay checks that it makes the same requests and consumes every recorded interaction
4. **Judge** - Each run's trace is checked against 13 invariant families, such as tool pairing, budget accounting and journal fold. Each family reports whether it ran and on how much input
5. **Keep** - A failure the nightly corpus finds is promoted into the fixed corpus as an exact program, before or with its fix

CI runs the fixed corpus on every pull request and a rotating corpus every night, whose seed window changes with the day. A result is scoped to a versioned execution profile, which names the installed extensions and what is excluded. `make dst` runs the full sweep of 53 targets.

Learn more: [DST technical report](papers/motoko-dst-report/DRAFT-current.md) | [Ports](src/core/ports.ail) | [Invariants](src/core/dst_invariants.ail) | [CI corpora](.github/workflows/dst-corpora.yml)

---

## Mutation Testing

Motoko mutates its own source to test its tests: a check covers a rule only when breaking that rule makes that check fail. The procedure runs when a piece of work is handed in for acceptance:

1. **One mutant per rule** - For each rule the design decision states, write a source edit that breaks that rule and nothing else
2. **Predict** - Name the check that should fail for each mutant, before running anything
3. **Run** - Apply one mutant at a time, run the checks, restore the source
4. **Judge** - A kill is the named check failing. A different check failing, a compile error, a crash or a timeout is not a kill
5. **Follow up** - A survivor is a finding. It gets a new check, or a sentence on why no input can tell the two versions apart

The table of mutants and results is committed with the work as evidence. This is a review step and not a CI gate, since each mutant costs a rebuild and a test run. Two cheaper forms are built in: `make verify_mutations` runs in CI and mutates guards under Z3 contracts (it edits files in place, so run it alone locally), and the DST suites change one field of a valid input per row to test their validators.

Learn more: [The rule](.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md) | [An acceptance run](.agent/projects/011_improve_test_axises/evidence/judge-recoveries/acceptance-ce9cb247/README.md) | [The spike that found two gaps](.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md)

---

## Limits

- **Simulation boundary** - The modeled environment excludes the TypeScript host, the operating system and external services; extension coverage is specific to a profile
- **Specifications** - Invariants address declared structural properties; contracts cover a small subset of pure functions
- **Oracle sensitivity** - Mutants are chosen by hand and give local evidence; there is no drawn mutant population and no mutation score
- **External validity** - Simulated runs say nothing about model quality or task success

---

## Development

```bash
make build         # Sync packages, type-check the core, build the TUI
make test          # Core runtime tests
make verify_core   # Z3 contract verification
make dst           # Full simulation sweep
```

**Guides:**
- [Running Motoko](docs/running.md) - Agent sandbox, dev container, native install and usage
- [Configuration](docs/configuration.md) - Profiles and model identifiers
- [Extensions](docs/extensions.md) - The extensions in this repo and how to write one
- [CONTRIBUTING.md](CONTRIBUTING.md) - Issue routing and contracts on `src/core/`

---

## Project Structure

```
motoko_agent/
├── src/core/       # Production runtime, simulation models, invariants, journal
├── src/tui/        # TypeScript host and terminal UI
├── src/eval/       # Journal-derived evaluation
├── packages/       # Extension packages, extension ABI, conformance suite
├── scripts/dst/    # Simulation runners, corpus gates and controls
├── docs/           # Running, configuration and extension guides
├── papers/         # DST technical report
└── .agent/         # Design archive (ADRs, plans, reviews, PR records)
```

---

## Credits

Motoko is inspired by and borrows from these projects:

- **[Pi Coding Agent](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/)** by Mario Zechner - Extension philosophy
- **[pi-tui](https://github.com/badlogic/pi-mono)** by Mario Zechner - The terminal UI library that Motoko's TUI is built on
- **[Oh-My-Pi](https://github.com/can1357/oh-my-pi)** - Efficient tools
- **[little-coder](https://github.com/itayinbarr/little-coder)** - Benchmark harness

---

*For AI agents: Coding-agent harness written in AILANG, with deterministic simulation testing of its production session driver. Run `ailang prompt` before writing `.ail` files and `make check_core` after changing `src/core`. See [CONTRIBUTING.md](CONTRIBUTING.md) for contract rules and issue routing.*
