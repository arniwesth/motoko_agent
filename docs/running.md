# Running Motoko

The two easiest ways to run Motoko are containers that come with the whole toolchain installed. They work on the same checkout, so you can use them side by side.

| | [Agent sandbox](#agent-sandbox) | [VS Code dev container](#vs-code-dev-container) |
|---|---|---|
| What it is | A confined container that Motoko and its delegates live in | A regular VS Code dev container |
| Good for | Letting agents work, including unattended | Editing, reading and reviewing with VS Code attached |
| Started from | A terminal on the host | *Reopen in Container* in VS Code |
| Privileges | No `sudo`, SSH or Docker socket; egress only through a proxy; GitHub only as a bot account | `sudo`, and VS Code forwards your own GitHub credentials |

A [native install](#native-install) is the third option, for when you would rather not use Docker.

## API keys

All three read provider keys from a `.env` file in the repo root (gitignored):

```bash
OPENROUTER_API_KEY=sk-or-...
```

The default profile uses an OpenRouter model, so that one key is enough to start. `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY` and `EXA_API_KEY` (web search) are picked up the same way. [Model identifiers](configuration.md#model-identifiers) lists which key each model string needs.

## Agent sandbox

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

Full details, the acceptance checks and the known gaps are in [.devcontainer/agent_sandbox/README.md](../.devcontainer/agent_sandbox/README.md).

## VS Code dev container

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

This container has `sudo`, and VS Code forwards your own credentials into it, so treat it as your workspace rather than as a place to leave an agent unattended. Ports, GitHub credentials and the observability setup are covered in [.devcontainer/README.md](../.devcontainer/README.md).

## Native install

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
