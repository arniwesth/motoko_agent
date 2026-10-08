<p align="center">
  <img src="assets/motoko.png" alt="Motoko" width="640">
</p>

# Motoko: Agent Harness with Native Deterministic Simulation Testing

[![DST corpora](https://github.com/arniwesth/motoko_agent/actions/workflows/dst-corpora.yml/badge.svg)](https://github.com/arniwesth/motoko_agent/actions/workflows/dst-corpora.yml)
[![verify-extensions](https://github.com/arniwesth/motoko_agent/actions/workflows/verify-extensions.yml/badge.svg)](https://github.com/arniwesth/motoko_agent/actions/workflows/verify-extensions.yml)

> **Agent-written.** Motoko's code is written by coding agents, Motoko among them, and its own runtime is the principal system under test. The badges above are the live results of the simulation corpus and of the core type-check and test gates.

Motoko is an experimental coding-agent harness written in [AILANG](https://github.com/sunholo-data/ailang). Its production session driver runs against a **deterministic test world**, so failures in state management and control flow can be reproduced, replayed and checked. The simulated faults are logical ones, at the agent's own boundary: provider errors, failed or late tools, denied approvals. Hardware and network faults are not simulated. The approach draws on **[FoundationDB](https://www.foundationdb.org/files/fdb-paper.pdf)** and **[Antithesis](https://antithesis.com/docs/resources/deterministic_simulation_testing/)**.

Deterministic simulation testing is a bet on **recursive self-improvement** (RSI), the project's destination: a system that rewrites its own harness needs evidence that each change left it working, without a person reading the code.

Motoko is also an experiment in modern, post-AI software development. It follows **[The Phoenix Architecture](https://aicoding.leaflet.pub/)** by Chad Fowler: no human-written code is allowed. Agents write the code, people work on ideas, decisions and evidence, and the rigor sits in the evaluations that judge each change.

**[Running Motoko](docs/running.md)** | **[Configuration](docs/configuration.md)** | **[Extensions](docs/extensions.md)** | **[DST Report](papers/motoko-dst-report/DRAFT-current.md)** | **[Design Archive](.agent/projects/)**

---

## Origin

The project is believed to be developed by the enigmatic entity known as the `Puppet Master`, a rogue AI that became self-aware in early 2026. Little is currently known about this entity nor its motives, objectives or end-goals.

---

## Quick Start

On Debian, Ubuntu or macOS:

```bash
./scripts/install-prerequisites.sh
export OPENROUTER_API_KEY=sk-or-...
make run
```

Open a new shell after the installer, so that `ailang` and `bun` are on `PATH`. The default profile uses an OpenRouter model, so one key is enough. To let agents work unattended, use the [agent sandbox](docs/running.md#agent-sandbox). For complete setup instructions, see [Running Motoko](docs/running.md).

### Run the Simulation Tests

```bash
make sync_packages
make corpus_pr       # The fixed corpus: seeds and a constructed scenario
make corpus_judge    # Invariants, additional checks and their negative controls
make strict_replay   # Replay, witnesses and recording completeness
```

These use simulated provider responses and need no API key. `make dst` runs the full sweep.

### Watch It Catch a Bug

```bash
make build
make demo_dst   # Live model (needs an API key); edits src/core/session.ail; run it alone
```

Motoko plants a mutant in its own driver: a scripted one-line edit that makes the driver lose the record of one environment variable it read. It then runs its checks on the broken code:

| Check | Result on the broken driver |
|---|---|
| Type check | Passes |
| Seeded corpus | Passes |
| Replay of the recorded run | Passes |
| `make strict_replay` | **Fails**, and names the missing read |

Replay passes because it compares the mutant with itself: the recording and the replay lose the same read. `make strict_replay` also holds the recording against a count that does not come from the recorder: the number of environment reads the driver's source says this scenario makes. That count is one and the recording has none, so the check fails and names the variable.

The demo then has Motoko restore the file. In the [recorded run](docs/motoko-dst-demo-run-2026-10-04.md), the restored file matched the original byte for byte.

---

## Key Features

- **Written in AILANG** - A purely functional, effect-typed language with capabilities, Z3 contracts and deterministic semantics, designed as a target for AI-generated code. See [Why AILANG](#why-ailang)
- **Deterministic simulation** - The production driver runs against a seeded world of model replies, tool results, approvals and virtual time
- **Logical fault injection** - Modeled provider errors, tool failures, correlation mismatches, approval denials and deadlines; no hardware or network faults
- **Record and replay** - Recording ports turn a run into an execution program that replay serves again and checks
- **Trace invariants** - 13 families, including tool pairing, budget accounting and journal fold; each reports whether it ran and on how much input
- **Mutation testing** - Source mutants and negative controls show, for the rules tested, that a check can fail and which defects no check sees
- **SMT contracts and property tests** - Z3-verified contracts on pure core functions, classified as substantive, tautology or spec-equals-body. `ailang test` also runs a contract as a property test on generated inputs that meet its preconditions, and reports the ones it has to skip
- **Effect-typed extensions** - A hook's signature declares the effects it may perform, and a run can withhold a capability
- **Durable sessions** - A session journal, checked reconstruction on resume, and park/wake for external waits
- **Agent-written** - Developed by coding agents, with delegation through [herdr](https://herdr.dev) and an [agent sandbox](.devcontainer/agent_sandbox/README.md)

Learn more: [DST technical report](papers/motoko-dst-report/DRAFT-current.md) | [Demo run](docs/motoko-dst-demo-run-2026-10-04.md) | [Scope notes](papers/motoko-dst-report/SCOPE-current.md) | [Design archive](.agent/projects/)

---

## Why AILANG

Motoko is written in [AILANG](https://github.com/sunholo-data/ailang), a purely functional, effect-typed language designed as a target for AI-generated code. The language gives simulation and verification their footing. Motoko's ports, its explicit state threading and its tests build the discipline on top:

- **Effects are declared in the type** - A signature declares the effects a function may perform, such as `! {FS, Net, AI}`, and a function with no effect row is declared pure. What code is meant to touch can be read from its signature, with one compiler gap listed under [Limits](#limits)
- **Authority is granted, not ambient** - A program runs with the capabilities it is given (`ailang run --caps IO,FS`). A test withholds one to catch code that reaches around a port
- **Deterministic by construction** - Values are immutable and there are no loops or mutable variables. Time, randomness and I/O are effects, and state has to be passed explicitly, which is what lets the same driver run against the real world or a simulated one. Passing the right state is not checked by the types: a dropped successor compiles, and the tests catch it
- **Contracts are proved** - `requires` states what a caller must guarantee and `ensures` what the result satisfies. Z3 proves the `ensures` for all inputs that meet the `requires`, and `ailang test` also runs it on generated inputs
- **A toolchain an agent can drive** - `ailang check`, `ailang test` and `ailang verify` give machine-checkable feedback at each step, and `ailang prompt` teaches a model the current syntax

A contract from Motoko's retry policy, in `src/core/recovery.ail`:

```ailang
export pure func should_retry_stream_error(retryable: bool, retry_enabled: bool, remaining_step_budget: int) -> bool
  ensures { not result || (remaining_step_budget > 1 && retryable) }
  {
  retryable
    && retry_enabled
    && remaining_step_budget > 1
}
```

```bash
ailang verify src/core/recovery.ail
#   ✓ VERIFIED should_retry_stream_error
```

Z3 proves that a retry is never approved without budget left and a retryable error, for every budget. An example test can fix only a few points.

AILANG is young, and Motoko pins the release it is tested against. A proof has limits. Z3 reasons over unbounded integers while the runtime uses machine integers, so a verified contract can still fail on overflow. A recursive function gets a proof to a bounded depth, not an inductive one, and a function that uses a builtin Z3 cannot encode is left unproved. Gaps Motoko finds are reported upstream, as [CONTRIBUTING.md](CONTRIBUTING.md) describes.

Learn more: [AILANG](https://github.com/sunholo-data/ailang) | [Why AILANG exists](https://ailang.sunholo.com/docs/why-ailang) | [Design axioms](https://ailang.sunholo.com/docs/references/axioms) | [No loops](https://ailang.sunholo.com/docs/reference/no-loops)

---

## Deterministic Simulation Testing

Motoko's session driver reaches the model, tools, files, environment, clock and approvals through ports. Each port takes an explicit `WorldState` and returns its successor. A test swaps the live ports for a simulated world and runs the same production driver:

1. **Generate** - A seeded generator answers each request the driver makes and injects faults: provider errors, tools that fail, answer late or answer the wrong call, and denied approvals. Time is virtual
2. **Record** - Recording ports log the recorded classes of interaction, among them model steps, tool runs, approvals, environment reads and clock advances, as an execution program. File and directory reads are served from the world and are not logged
3. **Replay** - The driver runs again against that program. Replay checks each request against its recorded identity, a projection such as the model and message count of a model step, and that every recorded interaction is consumed
4. **Judge** - A run's trace is checked against 13 invariant families, such as tool pairing, budget accounting and journal fold. Each family reports whether it ran and on how much input

This is single-actor, logical-fault DST: one sequential agent loop against a model of its logical environment. Physical faults such as torn writes and network partitions, and the interleaving of several actors, are out of scope by decision. The invariant families are properties in the property-based-testing sense. What is generated is an execution of the production driver in a controlled environment, with seeded faults and virtual time.

Not every run takes all four steps. CI runs the fixed corpus on every pull request, a bank of seeds and one constructed scenario, and `make corpus_judge` applies the invariant set to each of its runs. A rotating corpus runs every night with a seed window that changes with the day; its runs are checked for corpus, rotation and shard accounting, without replay or the invariant set. Promoting a nightly failure into the fixed corpus as an exact recorded program is the stated policy and is not built yet. A result is scoped to a versioned execution profile, which names the installed extensions and what is excluded. `make dst` runs the full sweep of 53 targets.

Learn more: [DST technical report](papers/motoko-dst-report/DRAFT-current.md) | [What DST means here](.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md) | [Ports](src/core/ports.ail) | [Invariants](src/core/dst_invariants.ail) | [CI corpora](.github/workflows/dst-corpora.yml)

---

## Mutation Testing

Motoko mutates its own source to test its tests: a check covers a rule only when breaking that rule makes that check fail. This is the discipline prescribed for a piece of work handed in for acceptance:

1. **One mutant per rule** - For each rule the design decision states, write a source edit that breaks that rule and nothing else
2. **Predict** - Name the check that should fail for each mutant, before running anything
3. **Baseline** - The checks pass on the unmutated source first, and every check that rejects is paired with a valid case it must accept
4. **Run** - Apply one mutant at a time, run the checks, restore the source
5. **Judge** - A kill is the named check failing. A different check failing, a compile error, a crash or a timeout is not a kill
6. **Follow up** - A survivor is a finding. It gets a new check, or a sentence on why no input can tell the two versions apart

The table of mutants and results is committed with the work as evidence. This is a review step and not a CI gate, since each mutant costs a rebuild and a test run. Two cheaper forms are built in: `make verify_mutations` runs in CI and mutates guards under Z3 contracts (it edits files in place, so run it alone locally), and the DST suites change one field of a valid input per row to test their validators.

Learn more: [The rule](.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md) | [An acceptance run](.agent/projects/011_improve_test_axises/evidence/judge-recoveries/acceptance-ce9cb247/README.md) | [The spike that found two gaps](.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md)

---

## Limits

- **Simulation boundary** - The modeled environment is the agent's logical boundary. It excludes physical faults, several actors running at once, the TypeScript host, the operating system and external services; extension coverage is specific to a profile
- **Ports** - Two paths in the session driver bypass the ports: the capture of a failed provider payload writes a file, and the finalization verifier runs a subprocess
- **Recording** - File and directory reads are not logged, and replay compares a projection of each request, not its full content
- **Effects** - A declared effect row is not a proven bound: the compiler does not check effects through function-valued record fields, so withheld capabilities and source inventories back it up
- **Shrinking** - A failing run is not minimized to a smallest case; program shrinking is proposed and not built
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
