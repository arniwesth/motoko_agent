# Motoko
`Motoko` is a highly experimental agent harness based on the [AILANG](https://github.com/sunholo-data/ailang) language. 

It is designed to explore self-evolving, self-verifying software and largely follows the [The Phoenix Architecture](https://aicoding.leaflet.pub/): no human written code allowed.

The project is believed to be developed by the enigmatic entity known as the `Puppet Master`, a rogue AI that became self-aware in early 2026. Little is currently known about this entity nor its motives, objectives or end-goals.

Things are going to break.
<p align="center"><img src="assets/motoko.png" alt="Motoko" /></p>

## Table of Contents

- [Highlights](#highlights)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Extensions](#extensions)
- [Development](#development)
- [Project structure](#project-structure)
- [Contributing](#contributing)
- [Reference](#reference)

## Highlights

- **Autonomous execution** — plans and runs commands without pausing for approval
- **Loadable extensions** — context-aware execution, web search, graph-based code ops, multi-agent composition, MCP bridge
- **Terminal UI** — inline session rendering, `/model` picker, abort at any step
- **JSON profiles** — named configs under `.motoko/config/` for per-project or per-provider setups
- **VS Code dev container** — one-click development environment

## Installation

### Prerequisites

| Dependency | Version |
|---|---|
| Go | >= 1.22 |
| Bun | >= 1.x |
| Node.js | >= 18 |

Rust is optional (Omnigraph extension only). The install script handles all dependencies.

### Quick start

```bash
./scripts/install-prerequisites.sh   # Installs Go, Bun, Node, AILANG, TUI deps
export OPENROUTER_API_KEY=sk-or-...
make run
make run TASK="Fix the off-by-one error in parse_config"
```

### VS Code Dev Container

Open the repo in VS Code with the Dev Containers extension. The container pre-installs everything and builds the TUI automatically. Run `make run` inside.

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
  compaction; unknown models fall back to broad provider-family defaults or no
  compaction when the limit is unknown.
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

### How it works

1. The TUI spawns the AILANG runtime as a child process
2. The runtime loops up to `max_steps`:
   - Calls the LLM with full conversation history
   - Extracts and executes tool calls (bash, file ops, search, tests, extensions)
   - Appends observations and repeats
3. The loop ends when the LLM responds without a tool call, a tool signals completion, the step budget is exhausted, or `/abort` arrives

## Extensions

| Extension | Purpose | Requires | Notes |
|---|---|---|---|
| context_mode | Context-efficient tool execution | `context-mode` npm package | |
| exa_search | Web search via Exa API | `EXA_API_KEY` | |
| omnigraph | Graph-based code operations | `omnigraph` CLI | |
| compose | Multi-agent composition | Subagent model (optional) | Highly experimental, partly non-functional |
| mcp | MCP protocol bridge | MCP server endpoints | |

Enable by listing in `extensions.order` in your profile's `config.json`.

### Adding a new extension

The fastest path (AILANG ≥ 0.18.5) — scaffold a working extension package in one command:

```bash
cd ../ailang-packages
ailang init motoko-extension \
  --name <yourorg>/motoko_ext_<name> \
  --tools "Tool1,Tool2" \
  --effects "FS,Process,Env"
# → packages/motoko-ext-<name>/ ready to type-check, all 8 hooks no-op'd
```

Then edit `<name>.ail` to fill in the real tool logic, wire the package into `motoko_agent/ailang.toml` (`[dependencies]` + `[extensions].packages`), and run `ailang generate-extension-registry`.

Full walkthrough (incl. file-by-file content + common pitfalls): [Build Your First motoko Extension](https://ailang.sunholo.com/docs/guides/build-a-motoko-extension).

For publishing your extension to the AILANG package registry: [Publishing Your Package](https://ailang.sunholo.com/docs/guides/package-publishing).

## Development

```bash
make test          # Core runtime tests
make check_core    # Type-check all .ail modules
make build         # Full build: sync + check + build_tui
```

TypeScript frontend tests: `cd src/tui && bun run test`.

## Project structure

```
motoko_agent/
├── src/
│   ├── core/                   AILANG runtime (rpc, parse, prompts, supervisor)
│   │   └── ext/                Extensions (compose, context_mode, exa_search, mcp, omnigraph)
│   ├── tui/                    TypeScript terminal UI (pi-tui)
│   └── examples/
├── scripts/                    Install, run, sync-extension scripts
├── .motoko/config/             JSON profile configs
├── .agent/                     Design archive (plans, summaries)
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
