# Motoko context_mode Extension

`context_mode` is Motoko's wrapper around
[mksglu/context-mode](https://github.com/mksglu/context-mode). It exposes
context-mode operations as Motoko extension tools so an agent can index, search,
and reuse repository context without repeatedly reading large raw files into the
conversation.

The extension is intended for codebase archaeology and debugging tasks where the
agent needs to correlate several files but should keep the model context small.
It advertises tools such as `CtxDoctor`, `CtxStats`, `CtxIndex`, `CtxSearch`,
`CtxFetchAndIndex`, and their `ctx_*` aliases.

## Demo Prompts

Use these prompts to exercise token-saving behavior on non-trivial repo
questions.

### Architecture Trace

```text
Use context_mode to investigate the extension system in this repository and produce a concise architecture note.

Do not answer from memory. Use the Ctx* tools directly, not BashExec, for the context-mode part.

Task:
1. Index the relevant source files for Motoko's extension loading and tool advertisement path.
2. Find how an extension listed in `.motoko/config/observability/config.json` becomes available to the model as a tool.
3. Trace the path for `context_mode` specifically, from profile config to registry resolution to advertised tool schemas.
4. Identify the minimum set of files that matter and explain each file's role.
5. Report how many tool calls you used, and for each context-mode call, summarize why it avoided reading larger raw files.

Constraints:
- Keep the final answer under 500 words.
- Include exact file paths.
- Include at least one concrete example of a tool name that should appear because of context_mode.
- Do not dump full file contents.
```

### Debugging Investigation

```text
Use context_mode to answer this repository archaeology question with minimal context usage:

"Why would `context_mode` appear in `loaded_extensions` but not show any `Ctx*` tools to the model?"

Use CtxIndex/CtxSearch/CtxStats/CtxDoctor or their snake_case aliases as appropriate. Avoid reading entire files unless context_mode cannot answer. Your final answer must include:
- the suspected failure mode,
- the exact registration fields involved,
- the files that prove it,
- and a compact fix strategy.

Keep the final answer under 400 words and do not paste large snippets.
```
