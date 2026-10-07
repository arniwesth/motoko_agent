<p align="center">
  <img src="assets/motoko.png" alt="Motoko" width="640">
</p>

# Motoko: Agent Harness with Native Deterministic Simulation Testing

[![DST corpora](https://github.com/arniwesth/motoko_agent/actions/workflows/dst-corpora.yml/badge.svg)](https://github.com/arniwesth/motoko_agent/actions/workflows/dst-corpora.yml)
[![verify-extensions](https://github.com/arniwesth/motoko_agent/actions/workflows/verify-extensions.yml/badge.svg)](https://github.com/arniwesth/motoko_agent/actions/workflows/verify-extensions.yml)

> **Agent-written.** Motoko's code is written by coding agents, Motoko among them, and its own runtime is the principal system under test. The badges above are the live results of the simulation corpus and of the core type-check and test gates.

Motoko is an experimental coding-agent harness written in [AILANG](https://github.com/sunholo-data/ailang). Its production session driver runs against a **deterministic test world**, so failures in state management and control flow can be reproduced, replayed and checked.

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

Motoko breaks its own driver with a scripted one-line edit, which makes the driver lose the record of one environment variable it read. It then runs its checks on the broken code:

| Check | Result on the broken driver |
|---|---|
| Type check | Passes |
| Seeded corpus | Passes |
| Replay of the recorded run | Passes, because the recording and the replay share the gap |
| `make strict_replay` | **Fails**, and names the missing read |

Motoko then restores the file byte for byte. The [run note](docs/motoko-dst-demo-run-2026-10-04.md) records one such run.

---

## Key Features

- **Deterministic simulation** - The production driver runs against a seeded world of model replies, tool results, approvals and virtual time
- **Fault injection** - Modeled provider errors, tool failures, correlation mismatches, approval denials and deadlines
- **Record and replay** - Recording ports turn a run into an execution program that replay serves again and checks
- **Trace invariants** - 13 families, including tool pairing, budget accounting and journal fold; each reports whether it ran and on how much input
- **Oracle validation** - Negative controls and targeted mutations show that a check can fail
- **SMT contracts** - Z3-verified contracts on pure core functions, classified as substantive, tautology or spec-equals-body
- **Effect-typed extensions** - A hook's signature states the effects it may perform, and a run can withhold a capability
- **Durable sessions** - A session journal, checked reconstruction on resume, and park/wake for external waits
- **Agent-written** - Developed by coding agents, with delegation through [herdr](https://herdr.dev) and an [agent sandbox](.devcontainer/agent_sandbox/README.md)

Learn more: [DST technical report](papers/motoko-dst-report/DRAFT-current.md) | [Demo run](docs/motoko-dst-demo-run-2026-10-04.md) | [Scope notes](papers/motoko-dst-report/SCOPE-current.md) | [Design archive](.agent/projects/)

---

## Limits

- **Simulation boundary** - The modeled environment excludes the TypeScript host, the operating system and external services; extension coverage is specific to a profile
- **Specifications** - Invariants address declared structural properties; contracts cover a small subset of pure functions
- **Oracle sensitivity** - Controls and mutations give local evidence; no aggregate mutation score is reported
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
- [Writing an extension](docs/extensions.md)
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

## Background

Motoko's simulation testing draws on [FoundationDB](https://www.foundationdb.org/files/fdb-paper.pdf) and [Antithesis](https://antithesis.com/docs/resources/deterministic_simulation_testing/). Its agent-written development model follows [The Phoenix Architecture](https://aicoding.leaflet.pub/). Other influences are [Pi Coding Agent](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/), [Oh-My-Pi](https://github.com/can1357/oh-my-pi), [context-mode](https://github.com/mksglu/context-mode) and [little-coder](https://github.com/itayinbarr/little-coder).

---

*For AI agents: Coding-agent harness written in AILANG, with deterministic simulation testing of its production session driver. Run `ailang prompt` before writing `.ail` files and `make check_core` after changing `src/core`. See [CONTRIBUTING.md](CONTRIBUTING.md) for contract rules and issue routing.*
