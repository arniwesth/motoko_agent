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

The `bedrock` profile reuses the OpenAI-compatible path. Motoko never calls Bedrock directly — a local LiteLLM proxy at `http://127.0.0.1:4000/v1` translates OpenAI Chat Completions to Bedrock:

```text
Motoko -> AILANG OpenAI-compatible provider
       -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
       -> LiteLLM  (AWS_BEARER_TOKEN_BEDROCK + AWS_REGION)
       -> Amazon Bedrock
```

**Auth is bearer-token only.** Put these in `.env` (gitignored) or the shell:

```bash
AWS_REGION=eu-north-1          # a region where your account has Bedrock access
AWS_BEARER_TOKEN_BEDROCK=...   # Bedrock API key (never printed by the scripts)
```

Do **not** use `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, or a mounted `~/.aws` — `make bedrock_proxy` strips all of them from the LiteLLM subprocess so boto3 can't silently fall back to them.

Motoko/AILANG still need an `OPENAI_API_KEY` to satisfy the OpenAI-compatible client guard. For a no-auth local proxy use only the dummy value `motoko-litellm-local`; **never forward a real OpenAI key to the proxy** (the smoke targets set the dummy explicitly so a real key in `.env` is overridden).

#### One-time install

```bash
python3 -m venv .venv-litellm && .venv-litellm/bin/pip install 'litellm[proxy]' boto3
```

#### Start the proxy

```bash
make bedrock_proxy        # foreground; Ctrl-C to stop. Serves 127.0.0.1:4000
```

#### Layered smokes (run in order; stop at first failure)

```bash
make smoke_bedrock_litellm   # 1. proxy direct: /v1/models + /v1/chat/completions
make smoke_bedrock_ailang    # 2. AILANG std/ai.stepWithStream through the proxy
make smoke_bedrock_motoko    # 3. Motoko minimal task on PROFILE=bedrock
make smoke_bedrock_tools     # 4. native tool-use (forces one BashExec)
make smoke_bedrock           # all four in sequence
```

Layering keeps a Bedrock model/auth problem (layer 1) separate from an AILANG routing problem (layer 2) and a Motoko tool-loop problem (layers 3-4). Smoke logs go to `tmp/` (gitignored) with bearer tokens redacted.

Equivalent manual invocations:

```bash
OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
OPENAI_API_KEY=motoko-litellm-local \
ailang run --caps AI,IO --ai gpt-bedrock-claude-sonnet-4-5 --entry main scripts/smoke_bedrock_litellm.ail

OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock MOTOKO_CONFIG=bedrock \
make run TASK="Reply with exactly: bedrock smoke ok"
```

> **Profile flags:** pass both `PROFILE=bedrock` and `MOTOKO_CONFIG=bedrock`. `PROFILE` now propagates into the build prerequisites (`verify_extensions`), but setting both keeps every prerequisite and the runtime on the same profile regardless of shell state.

#### Model alias and inference profiles

The model field in `.motoko/config/bedrock/config.json` is an **alias**, not the Bedrock model ID. It's both the `--ai` name AILANG sees and the LiteLLM `model_name`, so the two must always match. The real Bedrock model ID lives only in the LiteLLM `model:` line.

The alias name is constrained by AILANG's provider guessing (`internal/ai/config.go GuessProvider`):

- It must start with `gpt` (not `gpt-5`) so AILANG picks the **OpenAI Chat Completions** path and honors `OPENAI_BASE_URL` → LiteLLM. `o1`/`o3`/`codex`/`gpt-5` prefixes route to the OpenAI Responses API instead.
- It must **not** start with `claude` or contain `anthropic` — either would make AILANG call the **direct Anthropic API** (needs `ANTHROPIC_API_KEY`, ignores `OPENAI_BASE_URL`), bypassing LiteLLM. This is why the alias can't be the raw `eu.anthropic.claude-...` Bedrock ID.
- It must not look like a `vendor/model` string (avoid `/`), which would route to OpenRouter.

So `gpt-bedrock-claude-sonnet-4-5` names the underlying model while staying on the LiteLLM path. The mapping in `scripts/bedrock-litellm.yaml`:

```yaml
model_list:
  - model_name: gpt-bedrock-claude-sonnet-4-5
    litellm_params:
      model: bedrock/eu.anthropic.claude-sonnet-4-5-20250929-v1:0
      aws_region_name: os.environ/AWS_REGION
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      drop_params: true
```

That inference profile is account/region-specific. If layer 1 fails with `The provided model identifier is invalid` or `Invocation ... with on-demand throughput isn't supported`, list what your account/region offers and update the `model:` line to an available **inference profile** ID/ARN (not a bare on-demand model ID):

```bash
aws bedrock list-inference-profiles --region "$AWS_REGION"
aws bedrock list-foundation-models  --region "$AWS_REGION"
```

#### AILANG binary note

The direct OpenAI fallback for unresolved `gpt-*` aliases must honor `OPENAI_BASE_URL`. The fix lives in the `ailang/` source checkout (`cmd/ailang/ai_handlers.go`, with a regression test in `cmd/ailang/openai_local_endpoint_test.go`). Until a fixed `ailang` is installed on `PATH`, the build at `ailang/.bin/ailang` is used automatically: `scripts/run-agent.sh` prefers it, and the AILANG smoke target points at it. To check whether your installed binary already has the fix:

```bash
go -C ailang test ./cmd/ailang/ -run TestSetupAIHandlerDirect_OpenAIUsesCustomBaseURL
```

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
