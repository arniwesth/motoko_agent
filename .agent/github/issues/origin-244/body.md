---
repo: arniwesth/motoko_agent
issue: 244
title: "With the flat .motoko/config.json layout the host does not read the profile: the run uses the host's default model, not agent.model"
---

## Summary

With the legacy flat layout, `<workdir>/.motoko/config.json`, the runtime loads the profile and
the host does not. The host therefore resolves the model without it and passes its own default,
`anthropic/claude-sonnet-4-6`, as `--model`, which overrides the profile's `agent.model` in the
runtime. A flat profile that names a cheap model silently runs on the default one.

It is the host-side half of what #241 fixed for the runtime side, and it was listed there under
"Not done here".

## Context

**Repro (`main` @ `21a8a96a`, AILANG v0.47.2).** The provider keys are taken out of the
environment so that nothing can be billed; the runtime then says which key it wanted, which is
enough to see which model it was launched for.

```sh
W=$(mktemp -d); mkdir -p "$W/.motoko"
printf '{"agent":{"model":"openrouter/motoko-test/the-profiles-model"}}\n' > "$W/.motoko/config.json"
env -u MODEL -u ANTHROPIC_API_KEY -u OPENROUTER_API_KEY -u OPENAI_API_KEY -u GOOGLE_API_KEY \
  MOTOKO_HEADLESS=1 MOTOKO_JSONL_OUTPUT=1 MOTOKO_CONFIG=default WORKDIR="$W" ENV_PORT=0 \
  ./scripts/run-agent.sh "say hi" | grep 'environment variable required'
```

**Observed.**

| layout | what the runtime asked for |
|---|---|
| the same file at `.motoko/config/default/config.json` | `OPENROUTER_API_KEY environment variable required` |
| flat, `.motoko/config.json` | `ANTHROPIC_API_KEY environment variable required (model claude-sonnet-4-6; …)` |

With the per-profile layout the run is launched for the profile's OpenRouter model. With the flat
layout it is launched for the host's default.

**Cause.**

- `src/tui/src/profiles.ts`, `resolveProfileConfigPath`: an absolute profile, then
  `<workdir>/.motoko/config/<profile>/config.json`, then `MOTOKO_REPO`'s. There is no flat rule.
  The runtime's loader has one (`config.ail`, `resolve_profile_dir`).
- `src/tui/src/index.ts`, `resolveProfileAgentConfig`, reads the profile through that function and
  gets nothing for a flat layout. `resolveRuntimeModel(process.env, profileAgent.model)` then
  falls through `MODEL` and the profile to `DEFAULT_RUNTIME_MODEL`.
- The host always passes the result as `--model`, and the runtime prefers `--model` to the
  `agent.model` its own loader read.

**What else the host reads from the same file,** and so also misses in the flat layout:
`agent.openai_base_url`, `agent.ai_options_json`, `theme`, the process timeout, the extension
order it shows, and the ClickStack block.

**Not affected:** a run with `MODEL` set, and every shipped profile, which are all per-profile.

## Expected

- With the flat layout and no `MODEL`, the run is launched for the profile's `agent.model`. The
  repro above is the check: it should ask for the OpenRouter key.
- The host and the runtime find the profile by one rule. `loaderProfileDir` in
  `runtime-process.ts` (from #241) already states the loader's three places and what the sandbox
  lets it read; `resolveProfileConfigPath` could be that function plus `config.json`.
- A test that holds it. `make verify_profile_dir_agreement` constructs a real spawn per layout and
  already reads the `--profile` it is given; the `--model` could be read the same way.
