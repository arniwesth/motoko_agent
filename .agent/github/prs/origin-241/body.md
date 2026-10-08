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

It is finding 1 of the review of #239, taken apart from that PR.

**It does not make the two agree by construction.** The host restates the loader's rules. A new
gate, `make verify_profile_dir_agreement`, compares the host's answer with the real loader's over
fourteen layouts, and one launch outside those is known to still differ (#242). See "The gate"
and "Not done here".

**A workflow file changes:** `.github/workflows/verify-extensions.yml`. The `core` job gains three
steps: set up bun, install the TUI's dependencies, run the gate. No job is added.

**Reviewed three times by Codex Sol on 2026-10-08.** Each round found defects in what the round
before had added, and each is fixed. See "Review".

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
`.ail` file under `src/` changes; one new script under `scripts/` is the gate's runtime half.

## Changes

- fix(tui): MOTOKO_PROFILE_DIR names the directory the config loader reads, flat layout included
- fix(tui): a profile config reached through a symlink does not count, as it does not for the sandboxed loader
- ci: a gate that the host's MOTOKO_PROFILE_DIR is the directory the runtime's loader reads
- build: move verify_profile_dir_agreement above dst_l2 so it does not collide with #239's target
- fix(tui): the profile directory rule follows the loader into MOTOKO_REPO, and stops misreading two names
- ci: the agreement gate goes through the real spawn, has a control, and is a step of the core job

6 files changed, and the record of #242.

| file | what |
|---|---|
| `src/tui/src/runtime-process.ts` | `loaderProfileDir(workdir, profile)`; `buildChildEnv` uses it; the `RuntimeProcess` constructor asks again after the mirrors, always |
| `src/tui/src/harness-dst.test.ts` | one block, sixteen tests, which `make dst_l2` runs in CI |
| `src/tui/scripts/verify-profile-dir-agreement.ts` | new: the gate's driver, a control and fourteen layouts |
| `scripts/verify_profile_dir_agreement.ail` | new: the gate's runtime half, the real loader |
| `Makefile` | `verify_profile_dir_agreement` |
| `.github/workflows/verify-extensions.yml` | three steps at the end of the `core` job |

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

`loaderProfileDir` asks the loader's three places in the loader's order:

1. `<workdir>/.motoko/config/<profile>/` when it holds a `config.json`;
2. else `<workdir>/.motoko/` when that holds a `config.json`;
3. else `<MOTOKO_REPO>/.motoko/config/<profile>/` when that holds one;
4. else the per-profile path, as before.

"Holds a `config.json`" means one the sandboxed child can read. AILANG v0.47.2 refuses a path
that goes through any symlink below `AILANG_FS_SANDBOX`, wherever the link points; its sandbox log
(`AILANG_FS_SANDBOX_DEBUG=1`) says "escapes sandbox" even for a link to a file inside the workdir.
So a config counts only when no component below the workdir is a link. A workdir that is itself
reached through a symlink reads its files normally, on the runtime and in the rule.

The third place is usually outside the workdir, where the sandbox stops the runtime reading it.
`mirrorProfileFromRepo` copies it into the first place before the spawn, which is why the
constructor asks for the variable again after the mirrors: a mirror can have just created the
per-profile directory, and the loader prefers that over a flat config. Before this, the
constructor overrode the variable only when an absolute profile had been mirrored under its
basename. The first version of this PR left the third place out, on the grounds that the runtime
cannot read it. It can when `MOTOKO_REPO` is inside the workdir, and the mirror does not run when
the workdir's own per-profile config exists as a symlink; see "Review".

## The gate

`make verify_profile_dir_agreement` asks both sides for real, and through the spawn itself. For
each of fourteen layouts:

- it constructs a real `RuntimeProcess`, so the mirrors run and the environment and arguments are
  a launch's own;
- the "ailang" that spawn runs is a wrapper, which takes the `--workdir` and `--profile` it was
  handed and runs the runtime's own loader with them, in the environment it was handed
  (`scripts/verify_profile_dir_agreement.ail`, which calls `config.load_config_from_cli` and
  imports nothing above `config`);
- the wrapper reports the loader's directory, its own `MOTOKO_PROFILE_DIR`, and the loader's exit
  status.

A layout passes when the loader exited 0, the two directories are the same, and that directory is
the one the layout should give. The loader's directory is what a real start reports as
`config_dir`. It is the loader and not a whole session: the gate takes about a second.

A control runs first. The loader does not read `MOTOKO_PROFILE_DIR`, so with that variable
pointing nowhere it must still name the real directory. A stand-in that echoes the variable back
would make every layout agree; the control refuses it.

```
OK control: the loader's answer does not come from MOTOKO_PROFILE_DIR
OK a per-profile config: .motoko/config/p
OK a flat config: .motoko
OK both: .motoko/config/p
OK neither: .motoko/config/p
OK a flat config, and a per-profile config.json that is a symlink to a file outside the workdir: .motoko
OK a flat config, and a per-profile config.json that is a symlink to a file inside the workdir: .motoko
OK a flat config, and a per-profile directory that is a symlink: .motoko
OK a per-profile config.json that is a symlink, and no flat config: .motoko/config/p
OK a flat config.json that is a symlink, and nothing else: .motoko/config/p
OK a flat config, in a workdir that is itself a symlink: .motoko
OK a flat config, and a profile directory whose name starts with two dots: ..personal
OK MOTOKO_REPO outside the workdir holds the profile (the spawn mirrors it): .motoko/config/p
OK MOTOKO_REPO inside the workdir holds the profile (the spawn mirrors it): .motoko/config/p
OK MOTOKO_REPO inside the workdir, and a local per-profile config.json that is a symlink: repo/.motoko/config/p
verify_profile_dir_agreement: host and runtime agree on all 14 layouts
```

It needs bun and AILANG, which no other target does. CI runs it as three steps at the end of the
`core` job. An earlier commit of this branch gave it a job of its own, which paid about two and
a half minutes of setup for a second of work; the `dst_l2` job installs bun and the TUI's
dependencies and runs its tests in about ten seconds, and that is what the `core` job now pays.
It is in neither `check_core` nor `DST_TARGETS`. If AILANG changes what its sandbox lets the
loader see, this goes red and says which side reads what.

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

4. A per-profile `config.json` that is a symlink staying inside the workdir counts, because only
   a link that leaves the sandbox is refused. **Did not hold.** A real launch showed the loader
   refusing it and taking the flat config. The rule and its test were changed before the commit.
5. Each of three mutants of the symlink rule fails the tests named for it. **Held for two; the
   third survived its first run.** The test for a symlinked workdir expected the per-profile
   path, which is also the fallback, so it passed with the rule broken. It now asks about the flat
   config and fails alone.

6. Each of four mutants of the gate's two subjects fails the layouts named for it. **Held**,
   four of four, one of them on the runtime's side.
7. After the third review, nine mutants against the gate and the host tests together, with the
   failing layouts and tests named first. **Seven held exactly. Two did not, and one more was
   caught in the wrong place:**
   - "the flat rule removed": I named the two-dots test among the failures. It passed, correctly:
     that profile's own directory is readable, so the flat rule is never reached.
   - "flat beats per-profile": I named one layout and missed a second, the two-dots layout, which
     also has both a flat config and a readable profile directory. It failed, correctly.
   - the runtime-side mutant was first stopped by the control, which then asked about a flat
     config, so no layout was run. The control now asks about the loader's first rule only, and
     the same mutant fails the five layouts named.

After this lands, a flat-layout run with a profile override shows `context_limit_resolved` as
`bounded`; a change that takes the variable back to the per-profile path unconditionally turns
the `dst_l2` job red; and a change to either side's rule that the other does not follow turns
the gate's step in the `core` job red.

## Test evidence

On `883c6ccf` plus the commit, in a worktree, AILANG v0.47.2.

| check | result |
|---|---|
| `make dst_l2` (`bun test src/harness-dst.test.ts`) | 25 pass, 0 fail; 16 of them new |
| TUI jest (`src/.*\.test\.ts`) | 446 tests pass in 43 suites. 5 suites fail to load, as on `main` |
| TUI `tsc --noEmit` | exit 0 |
| `make verify_profile_dir_agreement` | the control and fourteen layouts OK, exit 0, about a second |
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
| flat, plus a per-profile `config.json` that is a link to a file outside the workdir | `<workdir>/.motoko` | `200000`, `bounded`, `profile_override` |
| flat, plus a per-profile `config.json` that is a link to a file inside the workdir | `<workdir>/.motoko` | `200000`, `bounded`, `profile_override` |
| flat, plus a per-profile directory that is a link to a directory inside the workdir | `<workdir>/.motoko` | `200000`, `bounded`, `profile_override` |

Before the symlink rule, the first of those three resolved `unknown`, `profile_config_absent`
with the same loaded directory. A probe of the runtime's `fileExists` under the sandbox, with its
debug log on, gave `REJECT … escapes sandbox` for all three linked paths and `true` for a regular
file under a workdir that is itself a symlink.

What `compaction_ai` registers, from a probe that calls its `register_with_config` with the
variable set by hand to each value:

| `MOTOKO_PROFILE_DIR` | registered |
|---|---|
| `<workdir>/.motoko/config/default`, the old value | `threshold_pct: 75`, `keep_recent: 6` (the defaults) |
| `<workdir>/.motoko`, the new value | `threshold_pct: 42`, `keep_recent: 3` (the file) |

Seven mutants of `runtime-process.ts`, one at a time and restored. The first four were run on the
first commit and again after the second:

| mutant | tests that failed |
|---|---|
| the flat rule removed, which is the old behaviour | flat only; the spawned child, flat; the repo mirror; and, after the second commit, the three symlink shapes |
| the constructor recomputes only when the profile was renamed, the old condition | the repo mirror, alone |
| flat beats per-profile | per-profile with or without a flat config; the repo mirror |
| the constructor recomputes with the unresolved profile name | the absolute profile, alone |
| a config counts when `fs.existsSync` says so | the three symlink shapes |
| a config counts when its real path starts with the workdir's | the two shapes whose link stays inside |
| the real path is compared with the unresolved path | the symlinked workdir, alone, on the second run (see prediction 5) |

Four mutants for the first version of the gate, the failing layouts named before each run:

| mutant | layouts that failed | what the gate said |
|---|---|---|
| host: a config counts when `fs.existsSync` says so | the three with a flat config and a symlinked per-profile one | host exports `.motoko/config/p`, loader reads `.motoko` |
| host: the flat rule removed | the five that should give the flat directory | the same |
| host: flat beats per-profile | "both" | host exports `.motoko`, loader reads `.motoko/config/p` |
| runtime: `resolve_profile_dir` skips the flat config | the same five | host exports `.motoko`, loader reads `.motoko/config/p` |

Nine mutants after the third review, against the fourteen-layout gate and the 25 host tests
together. Layouts are numbered in the order printed above:

| mutant | gate layouts that failed | host tests that failed |
|---|---|---|
| host: a config counts when `fs.existsSync` says so | 5, 6, 7, 9, 14 | the three per-profile symlink shapes; the flat symlink; the spawn with `MOTOKO_REPO` and an unreadable local config |
| host: the flat rule removed | 2, 5, 6, 7, 10 | eight, every test that expects the flat directory |
| host: flat beats per-profile | 3, 11 | per-profile with or without flat; two dots; the repo mirror |
| runtime: `resolve_profile_dir` skips the flat config | 2, 5, 6, 7, 10 | none, as it should be: the host is unchanged |
| host: "outside the workdir" is `startsWith("..")` again | 11 | two dots |
| host: the `MOTOKO_REPO` rule removed | 14 | the two `MOTOKO_REPO`-inside tests |
| host: only the per-profile place uses the symlink rule | 9 | the flat symlink |
| host: the `MOTOKO_REPO` rule uses `fs.existsSync` | none | `MOTOKO_REPO` outside the workdir |
| the constructor always passes `--profile default` | 1, 3, 4, 8, 9, 11, 12, 13, 14 | the two `--profile` tests |

The seventh and the ninth are the reviewer's own: both left everything green before this commit.
Its two stand-in binaries are refused by the control: one that runs the real loader and then
exits 42 ("the loader did not run to the end"), and one that only echoes the variable and exits 0
("answered with MOTOKO_PROFILE_DIR itself").

The dedicated CI job passed on its only run, in 2 min 41 s, before it was removed. A trial merge
of this branch with #239's head is clean.

## Review

Codex Sol (`gpt-6.1-sol`) reviewed head `9dd9116f` on 2026-10-08, with #239's head and with the
two merged, and said to keep this in draft. Each finding was reproduced before it was acted on.

- **Fixed: the host's existence check did not match the sandboxed loader's.** A per-profile
  `config.json` that is a symlink made the host export the per-profile directory while the loader
  took the flat config. Commit `f753e904`, and the three launches above.
- **Not fixed, older than this PR, filed as #242: with `WORKDIR` beneath the repository the loader
  loads no profile at all.** The host passes a relative `--workdir` for a workdir under its own cwd, and
  under the sandbox the runtime resolves that against the workdir. Reproduced in both layouts,
  with and without this change: `config_dir` is a path that does not exist and no extension is
  loaded. The limit is still read through the absolute `MOTOKO_PROFILE_DIR`. Before this PR that
  already gave such a run the per-profile config's `agent.context_limit`; this PR extends the
  same to a flat config. So there a run can get a window from a config whose other settings were
  not loaded.
- **Taken: the host tests cannot show agreement with the core.** They assert the variable's
  value, and the spawned "runtime" is a shell script. The reviewer suggested a gate that compares
  the exported directory with the one the real runtime reports. That is
  `make verify_profile_dir_agreement`, above, which CI runs in the `core` job.
- **Confirmed by its own runs:** the 15 tests then present, `tsc`, the flat override resolving
  `bounded`, and `compaction_ai` registering 42 and 3 where it registered 75 and 6.

**Third review, head `a82dedba`.** It confirmed the symlink fix on real launches and found three
defects in what had been added since, each reproduced here against the runtime's loader first:

- **Fixed: the loader's third place was left out.** With `MOTOKO_REPO` inside the workdir and a
  local per-profile config that is a symlink, the loader takes the repo's profile and the host
  exported the unreadable local directory. The rule now asks all three places.
- **Fixed: a directory named with leading dots was treated as outside the workdir.** A profile
  given as `../../..personal` is `<workdir>/..personal` for the loader; the host sent it to the
  flat config.
- **Fixed: the gate accepted a loader that had failed.** It took any line starting `PROFILE_DIR`
  whatever the process then did, and a stand-in that echoed the variable passed all nine layouts
  without running AILANG. The exit status is now required, and the control tells the loader from
  an echo.
- **Fixed: two holes it showed with mutants of its own.** Nothing held the symlink rule for the
  flat config, and nothing held the `--profile` argument the spawn passes. Both now fail a host
  test and a gate layout.
- **Taken: the gate bypassed the constructor.** It now goes through a real `RuntimeProcess`.
- **Its remark that a job reusing `dst-setup` can go red on unrelated installs** no longer applies
  to a job of its own: the gate is a step of the `core` job, which depends on that setup anyway.
- **Not acted on:** the workflow header's "why there are five" jobs comment is stale; there are
  seven. It was stale before this PR.

## Not done here

- **`WORKDIR` beneath the repository loads no profile.** #242. The fix is in how the workdir
  reaches the runtime, which several extensions also read.
- **The gate runs the loader, not a whole launch.** A real start through `scripts/run-agent.sh`
  was done by hand for the launches in the table and is in no gate.
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
