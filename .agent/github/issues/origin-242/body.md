---
repo: arniwesth/motoko_agent
issue: 242
title: "With WORKDIR beneath the repo the runtime loads no profile: the host passes a workdir relative to its cwd, and the sandbox resolves it against the workdir"
---

## Summary

When `WORKDIR` is a subdirectory of the Motoko repo, the runtime starts normally and loads no
profile: no extensions, and defaults for everything else the profile's `config.json` sets. The
only sign is `loaded_extensions=(none)` in the banner. The host and the sandboxed runtime disagree
about what a relative workdir is relative to.

Found on 2026-10-08 in the second review of #239. It is independent of that PR and of #241.

## Context

**Repro (clean `main` @ `883c6ccf`, AILANG v0.47.2).** From the repo root:

```sh
W="$PWD/zz-probe/ws"; mkdir -p "$W/.motoko/config/default"
printf '{"agent":{"model":"openrouter/motoko-test/not-a-real-model"},"extensions":{"order":["compaction_structural"],"strict":false}}\n' \
  > "$W/.motoko/config/default/config.json"
env -u MODEL MOTOKO_HEADLESS=1 MOTOKO_JSONL_OUTPUT=1 MOTOKO_CONFIG=default WORKDIR="$W" ENV_PORT=0 \
  ./scripts/run-agent.sh "say hi" | grep '"config_dir"'
```

The model id is one the provider rejects, so the run costs nothing; `session_start` is emitted
before any provider call.

**Observed.** The first `session_start`:

| `WORKDIR` | `model` | `config_dir` | `loaded_extensions` |
|---|---|---|---|
| `<repo>/zz-probe/ws` | the profile's | `zz-probe/ws/.motoko/config/default` | `[]` |
| the same files in a directory outside the repo | the profile's | `<that dir>/.motoko/config/default` | `["compaction_structural"]` |

So the host reads the profile (the model reaches the runtime as `--model`), and the runtime's
loader does not. The same happens with the legacy flat `.motoko/config.json`, and on the #239 and
#241 branches.

**Cause.**

- `runtime-process.ts`'s `supervisorWorkdirArg` passes `--workdir` relative to the host's cwd when
  the workdir is beneath it. `scripts/run-agent.sh` changes into the repo first, so for a workdir
  under the repo that is `zz-probe/ws`. A workdir that is the cwd becomes `.`, and one outside it
  is passed as given.
- The child runs with `AILANG_FS_SANDBOX=<workdir>`. Under the sandbox the runtime resolves a
  relative path against the sandbox root, not against its cwd. A probe of `fileExists` with the
  sandbox set to `<repo>/zz-probe/ws` and the cwd at the repo root:

  ```
  EXISTS=false zz-probe/ws/.motoko/config.json
  EXISTS=true  ./.motoko/config.json
  EXISTS=true  .motoko/config.json
  EXISTS=true  <repo>/zz-probe/ws/.motoko/config.json
  ```

- So `config.ail`'s `resolve_profile_dir` looks for
  `<workdir>/zz-probe/ws/.motoko/config/default/config.json`, finds none of its three places, and
  returns the per-profile path it could not read. The two views agree only when the workdir is
  the host's cwd.

**What else is affected.**

- Certain, because they come from the same unread file: `extensions.strict`, the backend block,
  cost rates and tool settings all take their defaults.
- Likely, read and not run: anything else the runtime builds from `--workdir` as a path, for
  example `prompts.with_agents_context`, which looks for `AGENTS.md` in it.
- The context limit is the exception. It is read through `MOTOKO_PROFILE_DIR`, which the host
  exports as an absolute path, so a profile's `agent.context_limit` is honoured while the rest of
  that file is not.

**How often.** Of the 1,041 session logs in one long-used checkout that record a `config_dir`,
743 ran with the repo as the workdir, 298 with a workdir outside it, and none with one beneath it.
So this is a layout nobody there has used, not a failure anyone there has been living with.

## Expected

- A run with `WORKDIR` beneath the repo loads the same profile, and reports the same
  `loaded_extensions`, as the same files do in a directory outside the repo. The repro above is
  the check.
- A gate holds it: for a workdir that is the cwd, beneath it and outside it, the `config_dir` the
  real runtime reports is the directory that holds the profile.

Two candidate fixes, neither tried:

- **Pass the absolute workdir**, as already happens for a workdir outside the cwd. The hazard is
  the extensions that compare workdir paths as text. A comment in `buildChildEnv` records that
  setting `MOTOKO_WORKDIR` to an absolute path refused every herdr `Delegate`, because
  `ctx.workdir` was the relative `--workdir` and an absolute directory is never textually under
  `.`. Whether those checks already misbehave for a workdir outside the repo, where `--workdir` is
  absolute today, is worth finding out first.
- **Pass `.`**, since the sandbox root is the workdir. That fixes the file reads. Anything that
  uses the value as a process working directory would then run in the host's cwd, which is the
  repo and not the workdir, unless the child is also started in the workdir; and the runtime
  loads its own sources relative to its cwd.

Until it is fixed, a warning when the profile directory the runtime resolved does not exist would
at least make the condition visible. Today a run in this state looks like a run with a profile
that happens to load nothing.
