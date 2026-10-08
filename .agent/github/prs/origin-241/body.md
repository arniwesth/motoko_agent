---
repo: arniwesth/motoko_agent
pr: 241
branch: fix/host-profile-dir-follows-loader
ticket: null
title: "fix(tui): MOTOKO_PROFILE_DIR names the directory the config loader reads, so a flat config's agent.context_limit takes effect"
---

## Summary

The host exported `MOTOKO_PROFILE_DIR` as `<workdir>/.motoko/config/<profile>` unconditionally.
The core's config loader also accepts the legacy flat `<workdir>/.motoko/config.json`. With that
layout the variable named a directory that does not exist, and everything in the runtime that
reads the profile through the variable read nothing. This makes the variable name the directory
the loader will actually load.

It is finding 1 of the review of #239, fixed at its cause and apart from that PR.

**What changes for a flat-layout profile:**

- **`agent.context_limit` takes effect.** The limit resolver reads
  `$MOTOKO_PROFILE_DIR/config.json`. A flat config's override was loaded and ignored, so the limit
  resolved `unknown` and no compactor could trigger.
- **Six extensions start reading their own JSON.** `compaction_ai`, `mcp`, `a2a`, `compose`,
  `agentcli` and `ailang_tools` read `$MOTOKO_PROFILE_DIR/<ext>.json`. In the flat layout they
  registered with defaults. This is a behaviour change for anyone who has those files in a flat
  `.motoko/` and has been running on defaults without knowing it.
- **`agentcli`'s lock file moves** to `.motoko/agentcli-exec.lock`, for the same reason.

**What does not change:** a profile in the per-profile layout, which is every shipped one. No
`.ail` file changes.

## Changes

- fix(tui): MOTOKO_PROFILE_DIR names the directory the config loader reads, flat layout included

2 files changed.

| file | what |
|---|---|
| `src/tui/src/runtime-process.ts` | `loaderProfileDir(workdir, profile)`; `buildChildEnv` uses it; the `RuntimeProcess` constructor asks again after the mirrors, always |
| `src/tui/src/harness-dst.test.ts` | one block, six tests, which `make dst_l2` runs in CI |

## Governing docs

- `src/core/config.ail`, the comment on `resolve_profile_dir`: the lookup order this follows.
  Per-profile directory, then the flat `.motoko/`, then `MOTOKO_REPO`'s.
- `.agent/projects/001_DST/ADR-003-harness-boundary-dst-regrounded-on-system-prompt-materialization.md`:
  the Layer-2 file the tests are added to. It already carries one later block on the child's
  environment (PLAN-003's resume block).
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`: how the four
  mutants below were predicted and read.
- #239, "Review", finding 1: where this was found and reproduced.

## The rule

`loaderProfileDir` applies the loader's first two rules and nothing else:

1. `<workdir>/.motoko/config/<profile>/` when it holds a `config.json`;
2. else `<workdir>/.motoko/` when that holds a `config.json`;
3. else the per-profile path, as before.

The loader's third place, `<MOTOKO_REPO>/.motoko/config/<profile>/`, is not here because the
runtime cannot read it under `AILANG_FS_SANDBOX`. `mirrorProfileFromRepo` copies it into the first
place before the spawn, which is why the constructor asks for the variable again after the
mirrors: a mirror can have just created the per-profile directory, and the loader prefers that
over a flat config. Before this, the constructor overrode the variable only when an absolute
profile had been mirrored under its basename.

## Predicted outcome

1. A flat config with `agent.context_limit: 200000` on an uncatalogued model resolves `bounded`,
   `profile_override`, as the same file does in the per-profile layout. **Held.** Expected, but
   not written down before the run.
2. Each of four mutants fails the tests named for it and no others. Written to the session's
   scratch directory before the runs. **Held**, four of four.
3. I expected `ext_set_digest` to differ between the unfixed and the fixed flat run, as a witness
   that `compaction_ai` registers a different configuration. **Did not hold:** the digest is the
   same in all three runs, so it does not cover registered configuration values. The change is
   shown by a direct probe of the registration below.

After this lands, a flat-layout run with a profile override shows `context_limit_resolved` as
`bounded`, and a change that takes the variable back to the per-profile path unconditionally
turns the `dst_l2` job red.

## Test evidence

On `883c6ccf` plus the commit, in a worktree, AILANG v0.47.2.

| check | result |
|---|---|
| `make dst_l2` (`bun test src/harness-dst.test.ts`) | 15 pass, 0 fail; 6 of them new |
| TUI jest (`src/.*\.test\.ts`) | 436 tests pass in 43 suites. 5 suites fail to load, as on `main` |
| TUI `tsc --noEmit` | exit 0 |
| `make check_core`, `make dst` | not run: no `.ail` file changes. CI runs its jobs |

Against the real runtime, headless, JSONL, through `scripts/run-agent.sh`, with a model id the
provider rejects, so no paid call was made. The profile is two files: a `config.json` with
`agent.context_limit: 200000` and both compactors, and a `compaction_ai.json` with
`threshold_pct: 42`.

| run | loaded config dir | `context_limit_resolved` |
|---|---|---|
| flat layout, `main` as it is | `<workdir>/.motoko` | `0`, `unknown`, `profile_config_absent`, `model_not_in_catalogue` |
| flat layout, with the fix | `<workdir>/.motoko` | `200000`, `bounded`, `profile_override` |
| the same files per-profile, with the fix | `<workdir>/.motoko/config/default` | `200000`, `bounded`, `profile_override` |

What `compaction_ai` registers, from a probe that calls its `register_with_config` with the
variable set by hand to each value:

| `MOTOKO_PROFILE_DIR` | registered |
|---|---|
| `<workdir>/.motoko/config/default`, the old value | `threshold_pct: 75`, `keep_recent: 6` (the defaults) |
| `<workdir>/.motoko`, the new value | `threshold_pct: 42`, `keep_recent: 3` (the file) |

Four mutants of `runtime-process.ts`, one at a time and restored:

| mutant | tests that failed |
|---|---|
| the flat rule removed, which is the old behaviour | flat only; the spawned child, flat; the repo mirror (its `buildChildEnv` line) |
| the constructor recomputes only when the profile was renamed, the old condition | the repo mirror, alone |
| flat beats per-profile | per-profile with or without a flat config; the repo mirror |
| the constructor recomputes with the unresolved profile name | the absolute profile, alone |

## Not done here

- **The host's own profile lookup does not know the flat layout either.** Read, not run:
  `profiles.ts`'s `resolveProfileConfigPath` looks in the per-profile directory and in
  `MOTOKO_REPO`. So with a flat config and no `MODEL` in the environment, the host finds no
  profile model and passes its default as `--model`, which overrides the flat config's
  `agent.model` in the runtime. A separate fix, with its own behaviour change.
- **A repo profile mirrored by the spawn shadows a flat config in the workdir.** The loader's order
  puts flat before `MOTOKO_REPO`; the mirror turns the repo's profile into the first place. Older
  than this change. The variable now follows what the loader will then load.
- **A hand-run `supervisor.ail` with no `MOTOKO_PROFILE_DIR`** still has its limit resolved from
  `.motoko/config/<MOTOKO_CONFIG or default>`, whatever `--profile` says. Fixing that means the
  resolver reads the profile that was loaded, which moves environment reads that five DST
  fixtures pin.
- **Five TUI suites fail to load under bun's jest in this container**, the same five as on `main`.
