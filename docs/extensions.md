# Extensions

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
| skills | | Skills as `SKILL.md` folders, indexed in one `Skill` tool and loaded on demand | A `.motoko/skills` folder |

## Writing an extension

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
