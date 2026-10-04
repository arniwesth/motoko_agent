# Motoko
`Motoko` is a highly experimental agent harness based on the [AILANG](https://github.com/sunholo-data/ailang) language. 

It is designed to explore self-evolving, self-verifying software and largely follows the [The Phoenix Architecture](https://aicoding.leaflet.pub/): no human written code allowed.

The project is believed to be developed by the enigmatic entity known as the `Puppet Master`, a rogue AI that became self-aware in early 2026. Little is currently known about this entity nor its motives, objectives or end-goals.

Things are going to break.
<p align="center"><img src="assets/motoko.png" alt="Motoko" /></p>

## Table of Contents

- [Highlights](#highlights)
- [Running Motoko](#running-motoko)
- [Configuration](#configuration)
- [Usage](#usage)
- [Extensions](#extensions)
- [Development](#development)
- [Project structure](#project-structure)
- [Contributing](#contributing)
- [Reference](#reference)

## Highlights

- **Autonomous execution** — plans and runs commands without pausing for approval
- **Two ready-made environments** — a confined agent container for letting agents work, and a VS Code dev container for hands-on work
- **Loadable extensions** — context-aware execution, web search, scratchpad cells, compaction, loop guards, MCP bridge
- **Delegation** — hands sub-tasks to other coding agents (`claude`, `codex`, `omp`) running in [herdr](https://herdr.dev) panes
- **Terminal UI** — inline session rendering, `/model` and `/profile` pickers, abort at any step
- **JSON profiles** — named configs under `.motoko/config/` for per-project or per-provider setups
- **Self-verification** — Z3 contracts on the pure core modules and a deterministic simulation testing (DST) sweep of the runtime

## Running Motoko

The two easiest ways to run Motoko are containers that come with the whole toolchain installed. They work on the same checkout, so you can use them side by side.

| | [Agent sandbox](#agent-sandbox) | [VS Code dev container](#vs-code-dev-container) |
|---|---|---|
| What it is | A confined container that Motoko and its delegates live in | A regular VS Code dev container |
| Good for | Letting agents work, including unattended | Editing, reading and reviewing with VS Code attached |
| Started from | A terminal on the host | *Reopen in Container* in VS Code |
| Privileges | No `sudo`, SSH or Docker socket; egress only through a proxy; GitHub only as a bot account | `sudo`, and VS Code forwards your own GitHub credentials |

A [native install](#native-install) is the third option, for when you would rather not use Docker.

### API keys

All three read provider keys from a `.env` file in the repo root (gitignored):

```bash
OPENROUTER_API_KEY=sk-or-...
```

The default profile uses an OpenRouter model, so that one key is enough to start. `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY` and `EXA_API_KEY` (web search) are picked up the same way. [Model identifiers](#model-identifiers) lists which key each model string needs.

### Agent sandbox

The sandbox in `.devcontainer/agent_sandbox/` is a container built for an agent rather than for a person. VS Code cannot attach to it, and everything the agent needs is baked into the image: the AILANG toolchain, herdr, the `claude`, `codex` and `omp` CLIs, and a headless browser. You drive it from a terminal on the host with `agent.sh`.

Its image, compose project and `make` targets still carry the profile's earlier name, `agent_confined`, so that is the name you will see in `docker ps` and in `agent.sh` output.

You need Docker on the host (OrbStack or Docker Desktop) and the `.env` file above; the launcher refuses to start without one.

```bash
# In a terminal on your machine, from the repo root. Not inside a container.
.devcontainer/agent_sandbox/agent.sh build       # first run only: build the image (several minutes) and start it
.devcontainer/agent_sandbox/agent.sh bootstrap   # first run only: TUI dependencies and herdr integrations
.devcontainer/agent_sandbox/agent.sh             # attach; detach with ctrl+b q
```

Attaching puts you in herdr, a terminal multiplexer for coding agents. Start Motoko in a pane:

```bash
make run
```

Panes keep running after you detach, and running `agent.sh` again re-attaches to them.

| Command | What it does |
|---|---|
| `agent.sh shell` | A bash prompt in the container, outside herdr |
| `agent.sh run <command>` | A one-shot command in the container, e.g. `agent.sh run make test` |
| `agent.sh session=<name>` | Start or re-attach to a second, independent herdr session |
| `agent.sh stop` | Stop and remove the container, ending every session |
| `agent.sh build` | Rebuild the image and restart |
| `agent.sh check` | Assert that the container still has the properties below |
| `agent.sh help` | Everything else |
| `make studio` | Start Herdr Studio in the container and print its browser URL (run on the host) |

What the sandbox takes away, and why it is where agents run:

- **No VS Code attach.** Attaching is what forwards your GitHub login and ssh-agent socket into a container, so this profile has no `devcontainer.json` and never appears in the *Reopen in Container* picker.
- **No `sudo`, no SSH client, no Docker socket.** The agent cannot install its way around a missing tool; new tools are an image rebuild from the host.
- **One way out.** The container sits on an internal network and reaches the internet only through a forward proxy that refuses private and reserved address ranges.
- **A bot identity.** Git and GitHub operations act as a machine user (`MOTOKO_BOT_GH_TOKEN`), never as you.
- **Keys from the environment only.** `.env` reads as empty inside the container; a curated list of keys is injected when the container is created. After editing `.env`, run `agent.sh stop` and start again.

The boundary is around the container, not the working tree: the checkout is shared with the host, so anything an agent writes there is on your disk too. `.devcontainer/`, `.vscode/` and `.git/hooks` are mounted read-only inside, which means changes to the sandbox itself are made from the host.

Full details, the acceptance checks and the known gaps are in [.devcontainer/agent_sandbox/README.md](./.devcontainer/agent_sandbox/README.md).

### VS Code dev container

A normal dev container, for working in the repo yourself.

1. Open the repo folder in VS Code with the Dev Containers extension installed and run **Dev Containers: Reopen in Container**.
2. Pick a profile:
   - **Motoko Agent** — the default, just the app container.
   - **Motoko Agent Observability** — adds ClickStack/HyperDX and a log collector, for shipping Motoko logs and traces.
3. When the container is ready, run Motoko from the integrated terminal:

```bash
make run
```

The image build installs every prerequisite and the post-create step builds the TUI. `.env` is optional here and is passed into the container whole.

This container has `sudo`, and VS Code forwards your own credentials into it, so treat it as your workspace rather than as a place to leave an agent unattended. Ports, GitHub credentials and the observability setup are covered in [.devcontainer/README.md](./.devcontainer/README.md).

### Native install

For Debian/Ubuntu and macOS, without Docker:

```bash
./scripts/install-prerequisites.sh    # or: make install
export OPENROUTER_API_KEY=sk-or-...   # or put it in .env
make run
```

The script installs everything Motoko needs:

| Dependency | Version |
|---|---|
| Go | >= 1.22 |
| Bun | >= 1.x |
| Node.js | >= 18 |
| AILANG | built from source at the tag pinned as `AILANG_REF` in the script |
| Z3, DuckDB, GitHub CLI, `context-mode` | installed by the script |

Optional extras: `--with-omnigraph` (Omnigraph CLI, needs Rust), `--with-lean` and `--with-lean-mathlib` (Lean 4 backend for scratchpad cells).

## Configuration

Profiles live under `.motoko/config/`. Select one with the Make `PROFILE` variable:

```bash
PROFILE=default make run
PROFILE=openrouter make run TASK="Add unit tests"
```

Generate a starter profile:

```bash
make init-config
make init-config PROFILE=myprofile
```

**Profile structure:**

```text
.motoko/config/
  default/
    config.json          Model, workdir, max_steps, extensions
    compaction_ai.json   (optional)
    compose.json         (optional)
    context_mode.json    (optional)
    exa_search.json      (optional)
    omnigraph.json       (optional)
```

**`config.json` shape:**

```json
{
  "agent": {
    "model": "anthropic/claude-sonnet-4-6",
    "workdir": ".",
    "max_steps": 50
  },
  "extensions": {
    "order": ["context_mode", "exa_search", "omnigraph"],
    "strict": false
  }
}
```

Per-extension JSON files are optional; if missing, hardcoded defaults apply.

`tools.process_timeout` (a duration such as `"300s"`) sets the runtime's
`--process-timeout`, the wall for `BashExec`/`RunTests` (30 s if unset); the
`MOTOKO_PROCESS_TIMEOUT` env var overrides it for one run.

Top-level `theme` picks the TUI colour scheme: `"tokyo-night"`, or unset for
the default PI colours (which follow your terminal's palette). The
`MOTOKO_THEME` env var overrides it for one run.

Precedence: hardcoded defaults < profile JSON < CLI args. API keys are always env vars.

### Model identifiers

Model selection and model discovery are separate:

- Runtime model resolution is shared by TUI and headless runs:
  `MODEL` env var > profile `agent.model` > `anthropic/claude-sonnet-4-6`.
- The TUI `/model` picker loads its baseline suggestion catalog from
  `.motoko/model-catalog.json`. Set
  `MOTOKO_MODELS_FILE=/path/to/model-catalog.json` to use
  a different catalog.
- Known per-model context windows also live in `.motoko/model-catalog.json`
  under `context_limits`. Motoko uses them for context telemetry and
  compaction. Unknown or uncatalogued models have no known limit, so
  compaction is skipped rather than guessed from provider-family prefixes.
- Dynamic suggestions from `OPENAI_BASE_URL` and OpenRouter are merged into the
  picker catalog at runtime. They do not override the selected runtime model.
- Ollama models are selected explicitly with `ollama/<model>`, either in
  `MODEL`, profile `agent.model`, or `.motoko/model-catalog.json`. They are not
  auto-discovered by the picker.

Motoko model strings are intentionally close to AILANG's provider routing
syntax, but a few prefixes have provider-specific meanings:

| Goal | Model string | Notes |
|---|---|---|
| Direct Anthropic | `anthropic/claude-sonnet-4-6` | Requires `ANTHROPIC_API_KEY`. |
| Direct OpenAI | `openai/gpt-4o` | Requires `OPENAI_API_KEY`, unless `OPENAI_BASE_URL` points at a local OpenAI-compatible endpoint. |
| Local OpenAI-compatible | `openai/deepseek-v4-flash` | Motoko strips the leading `openai/` before sending the model id to `OPENAI_BASE_URL`. Slashful local ids also work, e.g. `openai/google/gemma-4-26B-A4B-it` becomes `google/gemma-4-26B-A4B-it`. |
| Direct Google Gemini / Vertex | `gemini-2.5-flash` | AILANG selects the Google provider from the bare `gemini-*` prefix. It tries Vertex ADC first, then falls back to `GOOGLE_API_KEY` for AI Studio. |
| OpenRouter pinned model | `openrouter/google/gemini-2.5-flash` | Motoko strips only the outer `openrouter/`; OpenRouter receives `google/gemini-2.5-flash`. |
| OpenRouter routing policy | `openrouter/auto` | Preserved as-is for AILANG/OpenRouter routing. |
| Ollama | `ollama/llama3.2` | Preserved for AILANG to route to the native Ollama provider. Use any model name installed in your local Ollama server after the `ollama/` prefix. |

Important distinction: `google/gemini-2.5-flash` is an OpenRouter vendor/model
id in AILANG's routing rules, not the direct Vertex form. Use bare
`gemini-2.5-flash` for direct Google Gemini / Vertex.

## Usage

The same commands work in the sandbox, the dev container and a native install:

```bash
make run                                                   # build, then open the TUI and ask for a task
make run TASK="Fix the off-by-one error in parse_config"   # start with a task
make motoko                                                # start without rebuilding
PROFILE=openrouter make run                                # pick a config profile
MODEL=anthropic/claude-sonnet-4-6 make run                 # override the model for one run
```

`make run` rebuilds first: it syncs the extension packages, type-checks the core and builds the TUI. Once that has passed, `make motoko` skips straight to the TUI.

Inside the TUI:

| Command | What it does |
|---|---|
| `/model` | Switch model; opens a picker, or `/model <name>` switches directly |
| `/profile` | Switch profile; opens a picker, or `/profile <name>` switches directly |
| `/restart` | Restart the session, optionally with a different profile |
| `/abort` | Stop the runtime process |

For scripted runs, call the launcher directly:

```bash
./scripts/run-agent.sh --headless "Add unit tests for the parser"   # plain output, exits when done
./scripts/run-agent.sh --oneshot "Add unit tests for the parser"    # one task with the TUI, then exit
WORKDIR=/path/to/repo ./scripts/run-agent.sh                        # operate on another repo
```

### How it works

1. The TUI starts an environment server and spawns the AILANG runtime as a child process
2. The runtime loops up to `max_steps`:
   - Calls the LLM with full conversation history
   - Extracts and executes tool calls (bash, file ops, search, tests, extensions)
   - Appends observations and repeats
3. The loop ends when the LLM responds without a tool call, a tool signals completion, the step budget is exhausted, or `/abort` arrives

## Extensions

Extensions are AILANG packages under `packages/`. Enable one by listing it in `extensions.order` in your profile's `config.json`. Those marked ✓ are on in the default profile.

| Extension | Default | Purpose | Requires |
|---|---|---|---|
| context_mode | ✓ | Context-efficient tool execution | `context-mode` npm package |
| exa_search | ✓ | Web search via Exa API | `EXA_API_KEY` |
| scratchpad | ✓ | Persistent evaluation cells in Python, JS, AILANG and Lean | Lean cells need `--with-lean` |
| compaction_ai | ✓ | AI-powered conversation compaction | |
| compaction_structural | ✓ | Structural conversation compaction | |
| empty_stop_guard | ✓ | Continues once when a model returns an empty stop response | |
| progress_contract_guard | ✓ | Continues when a stop candidate reports the task as still in progress | |
| repetition_guard | ✓ | Breaks no-progress loops of repeated tool calls or answers | |
| herdr | ✓ | Delegates sub-tasks to coding agents in herdr panes | A herdr pane; inert anywhere else |
| agentcli | | Delegates sub-tasks to subscription-authenticated coding-agent CLIs | `codex` or `claude` CLI |
| a2a | | Delegates to configured A2A agents | Agent endpoints |
| compose | | Multi-agent composition | Subagent model (optional). Highly experimental, partly non-functional |
| mcp | | MCP protocol bridge | MCP server endpoints |
| omnigraph | | Graph-based code operations | `omnigraph` CLI |
| microrag | | Just-in-time knowledge retrieval via `ailang micro-rag` | |
| ailang_docs | | AILANG documentation lookups as typed tools | A workdir with an `ailang.toml` |
| ailang_tools | | AILANG-aware file tools: `ailang check` after every `.ail` write or edit | |
| decision_framework | | Injects a four-decision ladder into the system prompt | |

### Adding a new extension

Extensions are path dependencies of the root package, so a new one is added in this repo:

1. Copy `packages/motoko-ext-test-dummy/`, a minimal no-op extension, to `packages/motoko-ext-<name>/` and rename its package and module to `motoko_ext_<name>`.
2. Add it to `ailang.toml` twice: under `[dependencies]` (the path) and in `[extensions].packages` (name and version).
3. List `<name>` in your profile's `extensions.order`.
4. Regenerate the registry and build:

```bash
make registry_gen   # rewrites src/core/ext/registry_generated.ail from ailang.toml
make build          # syncs packages, type-checks, boot-probes the profile's extensions
```

Use `make registry_gen`, not the upstream `ailang generate-extension-registry`, which emits an older registry shape. The `ailang init motoko-extension` scaffolder has the same limitation: it targets extension ABI 2.x, while the packages here are on ABI 8.0 (`packages/motoko-ext-abi`). The ABI's design record is in `.agent/projects/017_extension_handling/`.

For publishing an extension to the AILANG package registry: [Publishing Your Package](https://ailang.sunholo.com/docs/guides/package-publishing).

## Development

```bash
make build              # Full build: sync packages + check_core + build_tui
make check_core         # Type-check src/core and boot-probe the active profile's extensions
make test               # Core runtime tests
make test_integration   # Integration tests
make verify_core        # Z3 contract verification of the pure core modules
make dst                # Deterministic simulation testing sweep
```

TypeScript frontend tests: `cd src/tui && bun run test`.

## Project structure

```
motoko_agent/
├── src/
│   ├── core/                   AILANG runtime (agent loop, session, journal, tools, DST drivers)
│   │   └── ext/                Extension host and the generated registry
│   ├── tui/                    TypeScript terminal UI and launcher (pi-tui)
│   ├── eval/                   Journal evaluation (admission runs, candidate checks)
│   └── examples/
├── packages/                   Extension packages (motoko-ext-*), the extension ABI, conformance suite
├── scripts/                    Install, run, smoke and verification scripts
├── tools/                      Repo tooling (PR pipeline, registry generator, code graph, inventories)
├── benchmarks/                 Benchmark harness
├── .devcontainer/              Dev container profiles and the agent sandbox
├── .motoko/config/             JSON profile configs
├── .agent/                     Design archive (projects, ADRs, plans, summaries, PR records)
├── omnigraph/                  Graph schema, queries, seed
└── papers/                     Research paper reading list
```

## Contributing

Bug reports, feature requests, and PRs welcome. The runtime spans two layers — Motoko (this repo) and AILANG (the language it's written in) — and each has its own reporting channel. See [CONTRIBUTING.md](./CONTRIBUTING.md) for the routing table and how to file AILANG-side issues via GitHub, the `ailang messages` CLI, or the public `submit_feedback` MCP tool.

## Reference

Motoko is heavily inspired by and borrows from the following projects:

- [Pi Coding Agent](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/) by Mario Zechner — extension philosophy
- [Oh-My-Pi](https://github.com/can1357/oh-my-pi) — efficient tools
- [context-mode](https://github.com/mksglu/context-mode) — context-efficient execution
- [little-coder](https://github.com/itayinbarr/little-coder) — benchmark harness

All credit for these ideas goes to those awesome projects.
