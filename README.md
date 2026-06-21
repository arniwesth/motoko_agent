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
PROFILE=bedrock make run TASK="Reply with exactly: bedrock smoke ok"
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

### Bedrock through LiteLLM

The `bedrock` profile uses the existing OpenAI-compatible path and expects a local LiteLLM proxy at `http://127.0.0.1:4000/v1`. Motoko does not call Bedrock directly.

Bearer-token-only setup:

```bash
export AWS_REGION=us-east-1
export AWS_BEARER_TOKEN_BEDROCK=...
litellm --config scripts/bedrock-litellm.yaml --host 127.0.0.1 --port 4000
```

Smoke from another shell:

```bash
curl -sS http://127.0.0.1:4000/v1/models

curl -sS http://127.0.0.1:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer motoko-litellm-local' \
  -d '{"model":"gpt-bedrock-smoke","messages":[{"role":"user","content":"Say bedrock smoke ok."}],"max_tokens":64}'

OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
OPENAI_API_KEY=motoko-litellm-local \
ailang run --caps AI,IO --ai gpt-bedrock-smoke --entry main scripts/smoke_bedrock_litellm.ail

OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock \
make run TASK="Reply with exactly: bedrock smoke ok"
```

Do not use `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, or mounted `~/.aws` for this profile. The LiteLLM config reads `AWS_BEARER_TOKEN_BEDROCK` and `AWS_REGION`; the dummy `OPENAI_API_KEY` only satisfies the OpenAI-compatible client path when the local proxy has no auth.

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
