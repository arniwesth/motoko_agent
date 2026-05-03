# Motoko

An AI coding agent harness built on [AILANG](https://github.com/sunholo-data/ailang). The runtime operates in **yolo mode** — it proposes and executes commands without pausing for confirmation. A TypeScript frontend built with [pi-tui](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/) renders sessions in the terminal and lets you switch models or abort mid-run.

---

## Architecture

```
bun src/tui/src/index.ts "task"
│
├── Embedded environment server  POST /exec :8080
│   Executes bash commands on behalf of the runtime process
│
└── AILANG supervisor process  src/core/supervisor.ail
    Reads JSON profile config plus CLI overrides
    Writes JSONL events to stdout
    Reads JSONL commands from stdin (abort, model_change)
```

The design archive in `.agent/plans/` documents how each component evolved. See `.agent/summaries/` for a chronological session log.

---

## Prerequisites

| Dependency | Version | Notes |
|---|---|---|
| Go | >= 1.22 | Required to build the AILANG runtime |
| Bun | >= 1.x | Required for the TypeScript frontend |
| Node.js + npm | Node >= 18 | Required for the context-mode MCP CLI |
| Rust + cargo | stable | Required only for optional Omnigraph CLI |

The install script handles all of the above automatically.

---

## Quick start

```bash
# 1. Install all dependencies (Go, Bun, Node, context-mode, AILANG, TUI deps)
./scripts/install-prerequisites.sh

# 2. Set your API key
export ANTHROPIC_API_KEY=sk-ant-...
# or: export OPENAI_API_KEY=sk-...
# or: export GOOGLE_API_KEY=...

# 3. Run
make run
# or with a task:
make run TASK="Fix the off-by-one error in parse_config"
```

The install script clones the AILANG runtime from `github.com/sunholo-data/ailang` (motoko branch), builds it, and installs it to `~/.local/bin/ailang`. No manual AILANG setup needed.

### VS Code Dev Container

Open this repo in VS Code with the Dev Containers extension installed. The container pre-installs Go, Bun, Node, context-mode, and AILANG. After creation it builds the TUI automatically.

Run `make run` inside the container.

---

## Configuration

Motoko loads committable project defaults from named JSON profiles under `.motoko/config/` at startup. Select a profile with `MOTOKO_CONFIG`:

```bash
MOTOKO_CONFIG=default make run
MOTOKO_CONFIG=openrouter make run TASK="Add unit tests for the parser"
```

Profile structure:

```text
.motoko/
  config/
    default/
      config.json          Core settings (model, workdir, tools, extensions)
      compose.json         Compose extension overrides (optional)
      context_mode.json    Context-mode extension overrides (optional)
      exa_search.json      Exa search extension overrides (optional)
      omnigraph.json       Omnigraph extension overrides (optional)
    openrouter/
      config.json          OpenRouter profile
```

Generate a starter config profile:

```bash
make init-config
make init-config PROFILE=myprofile
```

The profile's `config.json` controls core settings:

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

Per-extension JSON files are optional. An extension loads if listed in `extensions.order`; if its JSON file is missing, Motoko uses hardcoded defaults.

Config precedence: hardcoded defaults < profile JSON < CLI args. API keys are always environment variables.

---

## Extensions

Motoko supports loadable extensions that hook into the agent lifecycle (system prompt, tool policy, tool handling, response intercept, finalization).

| Extension | Purpose | Requires |
|---|---|---|
| context_mode | Context-efficient tool execution | `context-mode` npm package |
| exa_search | Web search via Exa API | `EXA_API_KEY` env var |
| omnigraph | Graph-based code operations | Omnigraph CLI (`omnigraph`) |
| compose | Structured multi-agent composition | Subagent model (optional) |
| mcp | MCP protocol bridge | MCP server endpoints |

Enable extensions by listing them in `extensions.order` in your profile's `config.json`.

---

## In-session commands

Type these into the command input at the bottom of the terminal:

| Command | Effect |
|---|---|
| `/model` | Opens a picker overlay (arrow keys to select, Enter to confirm) |
| `/model openai/gpt-4o` | Switches model immediately |
| `/abort` | Stops the runtime after its current step |
| Ctrl+C | Same as `/abort` |

---

## How it works

1. The frontend spawns the AILANG runtime as a child process.
2. The runtime emits a `session_start` event, then enters a loop:
   - Calls the LLM with the full conversation history
   - Extracts tool calls from the response
   - Executes native tools (BashExec, ReadFile, WriteFile, EditFile, Search, RunTests) or dispatches to extensions
   - Emits the observation and appends it to the conversation
   - Repeats up to `max_steps`
3. The loop ends when:
   - The LLM response contains no tool call (final answer)
   - A tool's stdout contains `COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`
   - The step budget is exhausted
   - An `/abort` command arrives on stdin

### Model strings

```
anthropic/claude-sonnet-4-6
anthropic/claude-opus-4-6
anthropic/claude-haiku-4-5
openai/gpt-4o
openai/gpt-4o-mini
google/gemini-2.5-flash
google/gemini-2.5-pro
```

Add an `openai_base_url` field to your config for custom OpenAI-compatible endpoints.

---

## Development

### Running tests

```bash
# Core runtime tests (85 tests)
make test

# TypeScript frontend tests
cd src/tui && bun run test

# Type-check all core modules
make check_core
```

| Test file | Tests | What is covered |
|---|---|---|
| `src/core/parse.ail` | 43 | `is_done`, `parse_cwd`, `looks_like_shell` — inline tests |
| `src/core/parse_test.ail` | 31 | `extract_fence`, `first_shell_line`, `extract_bash` — wrapper tests |
| `src/core/agents_md.ail` | 11 | `dirname`, `is_root` — inline tests |
| `src/core/ext/compose/compose_test.ail` | — | Composition language tests |
| `src/core/ext/compose/claimcheck_test.ail` | — | Claimcheck verification tests |

### Building

```bash
make build          # sync_packages + check_core + build_tui
make build_tui      # Build TypeScript frontend only
make check_core     # Type-check all .ail modules
```

---

## Project structure

```
motoko_agent/
├── SYSTEM.md                   Motoko system prompt (tool instructions, identity)
├── v0.12.1.md                  AILANG language teaching prompt (syntax + stdlib reference)
├── AGENTS.md                   Agent guidelines placeholder
├── README.md
├── Makefile
├── .gitignore
├── .vscode/                    VS Code settings + AILANG language extension
├── .devcontainer/              VS Code dev container
├── src/
│   ├── core/                   AILANG runtime modules
│   │   ├── ext/                Extension modules
│   │   │   ├── compose/        Multi-agent composition
│   │   │   ├── context_mode/   Context-efficient tool execution
│   │   │   ├── exa_search/     Web search
│   │   │   ├── mcp/            MCP protocol bridge
│   │   │   └── omnigraph/      Graph-based code operations
│   │   ├── rpc.ail             Core runtime entry point and main loop
│   │   ├── supervisor.ail      Config loading and boot
│   │   ├── parse.ail           Tool call extraction and parsing
│   │   ├── prompts.ail         System prompt and message formatting
│   │   └── ...
│   ├── tui/                    TypeScript terminal UI (pi-tui)
│   │   ├── src/
│   │   │   ├── index.ts        Entry point
│   │   │   ├── ui.ts           Terminal UI
│   │   │   ├── env-server.ts   Embedded bash execution server
│   │   │   ├── runtime-process.ts  AILANG subprocess wrapper + JSONL pipe
│   │   │   └── ...
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── examples/
│       └── hello_world/
├── scripts/
│   ├── install-prerequisites.sh    One-shot dependency installer
│   ├── run-agent.sh                Resolved-path entry point
│   └── sync-extension-packages.sh  Mirror extensions for runtime loading
├── .motoko/config/                 JSON profile configs
├── .agent/                         Design archive (plans, summaries, research)
├── omnigraph/                      Omnigraph schema, queries, seed, validator
├── papers/                         Curated research paper reading list
```
