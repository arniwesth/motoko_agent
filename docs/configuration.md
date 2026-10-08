# Configuration

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

`extensions.strict` (default `false`) makes the runtime refuse to start, with
an `error` naming the reason and exit code 2, when the profile would run with
less than it declares:

- an entry in `extensions.order` is not an installed extension,
- an extension registers no capability, or
- a compactor is loaded and the model's context limit is unknown, so the
  compactor could never run (see [Model identifiers](#model-identifiers)).

Without it the first two are skipped with a warning and the third starts with
a warning.

`tools.process_timeout` (a duration such as `"300s"`) sets the runtime's
`--process-timeout`, the wall for `BashExec`/`RunTests` (30 s if unset); the
`MOTOKO_PROCESS_TIMEOUT` env var overrides it for one run.

Top-level `theme` picks the TUI colour scheme: `"tokyo-night"`, or unset for
the default PI colours (which follow your terminal's palette). The
`MOTOKO_THEME` env var overrides it for one run.

Precedence: hardcoded defaults < profile JSON < CLI args. API keys are always env vars.

## Model identifiers

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
  Motoko warns about this once when the session starts, naming the model, why
  no limit was found and which loaded compactors cannot run; under
  `extensions.strict` a profile that loads a compactor refuses to start
  instead. To give such a model a window, add it under `context_limits`, or
  set `agent.context_limit` (a positive token count) in the profile's
  `config.json`. The profile value wins over the catalogue, because the window
  is a property of the endpoint serving the model. `agent.context_limit:
  "disabled"` declares that the profile runs without a window; it is neither
  warned about nor refused.
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
