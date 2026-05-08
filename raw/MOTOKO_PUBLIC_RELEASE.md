# Plan: motoko_agent Public Release

## Goal

Extract mature Motoko components from the private `ailang_agent` repo into a clean public `motoko_agent` repository, with a dev Docker setup, streamlined dependency installation (including AILANG fork), and a public-facing README.

## Non-goals

- Changing runtime behavior, extension logic, or TUI implementation
- Publishing benchmarks, training code, internal tooling, or experimental artifacts
- Creating a new AILANG fork — the existing `github.com/sunholo-data/ailang` (`motoko` branch) will be made public

---

## Phase 1: Define publishable file manifest

### Included (from current repo root)

```
motoko_agent/
├── SYSTEM.md                           (Motoko system prompt — tool instructions, identity)
├── v0.12.1.md                          (AILANG language teaching prompt — syntax + stdlib reference)
├── AGENTS.md                           (agent guidelines placeholder)
├── README.md                           (rewritten, Phase 4)
├── Makefile                            (trimmed, see Phase 6)
├── .gitignore                          (see Phase 6)
├── src/
│   ├── core/                           (all .ail modules + package manifest)
│   │   ├── AGENT.md                    (shared host/runtime contracts doc)
│   │   ├── ailang.toml                 (package manifest — exports modules ext depend on)
│   │   ├── agents_md.ail
│   │   ├── backend.ail
│   │   ├── cache.ail
│   │   ├── compress.ail
│   │   ├── config.ail
│   │   ├── context_usage.ail
│   │   ├── context_usage_test.ail
│   │   ├── env_client.ail
│   │   ├── parse.ail
│   │   ├── parse_test.ail
│   │   ├── prompts.ail
│   │   ├── prompts_test.ail
│   │   ├── rpc.ail
│   │   ├── supervisor.ail
│   │   ├── tool_contract.ail
│   │   ├── tool_runtime.ail
│   │   ├── types.ail
│   │   ├── version.ail
│   │   └── ext/
│   │       ├── registry.ail
│   │       ├── runtime.ail
│   │       ├── types.ail
│   │       ├── compose/
│   │       │   ├── ailang.toml         (extension package manifest)
│   │       │   ├── AGENT.md
│   │       │   └── (all .ail modules)
│   │       ├── context_mode/
│   │       │   ├── ailang.toml
│   │       │   └── (all .ail modules)
│   │       ├── exa_search/
│   │       │   ├── ailang.toml
│   │       │   └── (all .ail modules)
│   │       ├── mcp/
│   │       │   ├── ailang.toml
│   │       │   └── (all .ail modules)
│   │       └── omnigraph/
│   │           ├── ailang.toml
│   │           └── (all .ail modules)
│   ├── tui/                            (entire directory)
│   │   ├── src/
│   │   │   ├── banner-pixels.ts
│   │   │   ├── banner-runtime.ts
│   │   │   ├── banner-runtime.test.ts
│   │   │   ├── commands.ts
│   │   │   ├── commands.test.ts
│   │   │   ├── compose-claimcheck.ts
│   │   │   ├── compose_claimcheck.test.ts
│   │   │   ├── compose_guard_semiformal.test.ts
│   │   │   ├── compose-output-validator.test.ts
│   │   │   ├── config.ts
│   │   │   ├── config.test.ts
│   │   │   ├── env-server.ts
│   │   │   ├── env-server.test.ts
│   │   │   ├── env-server-main.ts
│   │   │   ├── index.ts
│   │   │   ├── init-config.ts
│   │   │   ├── json-highlight.ts
│   │   │   ├── json-highlight.test.ts
│   │   │   ├── models.ts
│   │   │   ├── models.test.ts
│   │   │   ├── runtime-process.ts
│   │   │   ├── runtime-process.stream-protocol.test.ts
│   │   │   ├── runtime-process.tool-progress.test.ts
│   │   │   ├── stream-markdown.ts
│   │   │   ├── stream-markdown.test.ts
│   │   │   ├── tool-plan-parser.ts
│   │   │   ├── tool-plan-parser.test.ts
│   │   │   ├── ui.ts
│   │   │   ├── ui.context-counter.test.ts
│   │   │   ├── ui.highlight.test.ts
│   │   │   ├── ui.stream-reconcile.test.ts
│   │   │   ├── ui.tool-render.test.ts
│   │   │   ├── ui.wait-state.test.ts
│   │   │   └── session-logger.ts
│   │   │   ├── ohMyPi/
│   │   │   │   ├── dispatcher.ts       (Oh My Pi tool dispatch integration)
│   │   │   │   └── session-adapter.ts  (Oh My Pi session adapter)
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── bun.lock
│   └── examples/
│       └── hello_world/
│           └── hello_world.ail
├── scripts/
│   ├── install-prerequisites.sh        (updated, Phase 2)
│   ├── run-agent.sh
│   └── sync-extension-packages.sh      (mirrors extensions for runtime loading)
├── .motoko/
│   └── config/
│       ├── default/
│       │   ├── config.json             (sanitized, Phase 5)
│       │   ├── compose.json
│       │   ├── context_mode.json
│       │   ├── exa_search.json
│       │   └── omnigraph.json
│       └── openrouter/
│           └── config.json             (no sanitization needed — already clean)
├── .agent/                             (design archive — plans, summaries, research, specs, learnings)
│   ├── plans/                          (70+ feature design plans)
│   ├── summaries/                      (50+ dated session summaries)
│   ├── research/                       (research notes and transcripts)
│   ├── specs/                          (protocol and UI specs)
│   ├── learnings/                      (post-mortems and lessons)
│   ├── notes/                          (progress notes)
│   ├── reviews/                        (review summaries)
│   └── issues/                         (issue notes)
├── omnigraph/                          (entire directory)
├── papers/
│   └── README.md                       (curated reading list — arXiv IDs, titles, Motoko relevance)
└── .devdocker/
    ├── Dockerfile                      (new, Phase 3)
    └── docker-compose.yml              (new, Phase 3)
```

### Explicitly excluded

- `ailang/` (vendored fork — users clone from `github.com/sunholo-data/ailang`)
- `runtime-patches/` (historical reference; AILANG fork carries the patches)
- `benchmarks/`, `benchmark_generared_files/`, `benchmark_result.md`, `polyglot-benchmark/`
- `training/`, `DR-Venus/`, `eval_results/`
- `misc/`, `tools/`, `little-coder/`
- `docs/`, `.ailang/`, `.bin/`, `.claude/`, `.omp/`, `.packages/`, `.motoko-store/`
- `CLAUDE.md`, `References.md`, `prompts.md`
- `.mcp.json`, `ailang.toml` (repo root), `ailang.lock`
- `debug/`, `artifacts/`, `tmp/`, `logs/`, `jest_0/`, `node_modules/`
- `src/snippets/`, `src/src/`
- `src/core/test-files/` (25 internal test fixtures, not part of test suite)
- `src/core/.ailang/` (build cache)
- `src/core/ext/test_dummy/`
- `.env`, `.export`, `.DS_Store`
- Current `.devcontainer/`
- `.agent/reports/` (20MB of build logs, traces — operational artifacts, not design archive)
- `.agent/fixtures/` (test spikes and patches)
- `papers/*.pdf` (52MB of arXiv PDFs — cited by ID in papers/README.md instead)

---

## Phase 2: Update install-prerequisites.sh

### Changes

1. **Add `clone_ailang()` function** — runs after `check_ailang()`:
   - If `ailang` not on PATH, clones `https://github.com/sunholo-data/ailang` (branch `motoko`) into `$HOME/.local/share/ailang`
   - Runs `go build ./cmd/ailang` inside
   - Copies binary to `$HOME/.local/bin/ailang`
   - Verifies with `ailang --version`

2. **Update `check_ailang()`** — if `ailang` missing, calls `clone_ailang()` instead of printing manual instructions

3. **Update `print_summary()`** — remove manual build instructions for AILANG; note that AILANG was auto-installed

### Deliverable

`scripts/install-prerequisites.sh` updated and self-contained.

---

## Phase 3: Create .devdocker/

### Dockerfile

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Go
ENV GO_VERSION=1.22.5
RUN ARCH=$(uname -m | sed 's/aarch64/arm64/; s/x86_64/amd64/') && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"

# Bun
COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bun

# Node.js 22.x
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

# context-mode CLI
RUN npm install -g context-mode

# AILANG runtime (clone + build from public fork)
RUN git clone --branch motoko https://github.com/sunholo-data/ailang /opt/ailang && \
    cd /opt/ailang && go build ./cmd/ailang && \
    cp ailang /usr/local/bin/ailang

# Set up workspace
WORKDIR /workspaces/motoko_agent
```

### docker-compose.yml

```yaml
services:
  motoko:
    build: .
    volumes:
      - .:/workspaces/motoko_agent
    ports:
      - "8080:8080"
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY:-}
    stdin_open: true
    tty: true
    command: >
      bash -c "
        cd /workspaces/motoko_agent/src/tui && bun install && bun run build &&
        cd /workspaces/motoko_agent &&
        echo 'Motoko ready. Run: make run'
        exec bash
      "
```

Note: `protobuf-compiler` dropped from Dockerfile. It's only needed for Omnigraph, and Omnigraph is an optional install the user runs inside the container if they want it.
Prerequisite: `github.com/sunholo-data/ailang` (`motoko` branch) must be public before the Docker build works, since the Dockerfile clones it at build time.

---

## Phase 4: Rewrite README.md

Complete rewrite for public audience. Structure:

1. **What is Motoko** — AI coding agent harness built on AILANG, yolo mode, terminal UI
2. **Architecture** — diagram (keep existing), explanation
3. **Prerequisites** — Go, Bun, Node.js (install script handles all)
4. **Quick start** —
   - `./scripts/install-prerequisites.sh` (clones+builds AILANG fork automatically)
   - Set API key env var
   - `make run` or `./scripts/run-agent.sh "your task"`
5. **Docker** — `docker compose -f .devdocker/docker-compose.yml up --build`
6. **Configuration** — `.motoko/config/` profiles, `make init-config`
7. **Extensions** — context_mode, exa_search, omnigraph, compose, mcp
8. **In-session commands** — `/model`, `/abort`, Ctrl+C
9. **How it works** — agent loop (bash block extraction, exec, observe, repeat)
10. **Development** — building, testing (`make test`, `make check_core`, `cd src/tui && bun run test`)
11. **Project structure** — updated tree

### Key changes from current README

- Remove all references to internal repos, local IPs, private model strings
- Remove legacy TOML migration notes
- Remove proxy/debugging section
- Remove headless CLI section (or reduce to one short note)
- Update model strings to current Claude/OpenAI/Google models only
- Add Docker quick start section
- Remove `runtime-patches/` references (directory excluded)
- Note that AILANG is auto-cloned by install script

---

## Phase 5: Sanitize config template

### `.motoko/config/default/config.json` changes

- `model`: `"anthropic/claude-sonnet-4-6"`
- Remove `openai_base_url`
- Remove `ai_options_json`
- `backend.port`: keep `8080`
- `extensions.order`: `["context_mode", "exa_search", "omnigraph"]` (compose and mcp load on-demand or user opts in)
- All other fields: keep defaults

---

## Phase 6: Trim Makefile

### Remove targets

- `codex`, `claude`, `prune`
- `sync_packages`, `serve_ailang`
- `run_test`, `run_test_local`
- `run_hello_world`
- `benchmark_hashline`, `md2audio_test`
- `test_omnigraph_e2e`, `test_context_mode_e2e`
- `test_dummy_extention_1`, `test_dummy_extention_2`
- Commented-out `train` target
- `LOCAL_BIN_DIR` and `AILANG_LOCAL_BIN` variables (AILANG expected on PATH)
- `build_ailang` and `check_ailang` targets

### Keep targets (with fixes)

- `sync_packages` — keep as standalone target (not in default build chain); dependency on `check_ailang` removed (assume `ailang` on PATH)
- `build` — `sync_packages check_core build_tui`
- `build_tui` — `cd src/tui && bun install && bun run build`
- `check_core` — type-check all `.ail` files in `src/core/` (dependency on `sync_packages` removed — not needed for type-checking)
- `test` / `test_core` — run AILANG core tests + compose tests (dependency on `check_ailang` removed — assume `ailang` on PATH)
- `run` — `build` + `./scripts/run-agent.sh`
- `install` — `./scripts/install-prerequisites.sh --with-omnigraph`
- `init-config` — `bun src/tui/src/init-config.ts --profile $(PROFILE) $(ARGS)`

### .gitignore

```
# Dependencies
node_modules/
src/tui/dist/

# Build caches
.ailang/

# Environment
.env

# OS
.DS_Store

# Session logs
.motoko/logfile/
.motoko-store/
```

---

## Phase 7: Verification

1. **Install script** — run `./scripts/install-prerequisites.sh` in a clean environment; verify AILANG clone+build works
2. **Docker** — `docker compose -f .devdocker/docker-compose.yml up --build`; verify shell is ready, `ailang --version` works
3. **Core tests** — `make test` passes all 85+ tests
4. **TUI build** — `make build_tui` succeeds
5. **Config init** — `make init-config` generates valid config
6. **Smoke run** — `make run TASK="list files in current directory"` starts without errors (needs API key)

---

## Execution order

1. Create `motoko_agent` repo structure with selected files
2. Create `papers/README.md` — curated reading list from the 26 arXiv PDFs (titles, IDs, one-line Motoko relevance)
3. Sanitize config and trim Makefile
4. Update install-prerequisites.sh
5. Create .devdocker/ files
6. Rewrite README.md
7. Write trimmed .gitignore
8. Test each deliverable
