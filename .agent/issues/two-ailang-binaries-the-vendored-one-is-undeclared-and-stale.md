# Two AILANG binaries on one tree: the agent runtime runs an undeclared, stale compiler that the gates do not

## Status

open — filed 2026-10-05 while measuring the isolation surface of DST work
(`tmp/ISOLATION-FINDINGS.md`), after an Opus 5.5 design review (`tmp/ISOLATION-REVIEW.md`,
"Adjacent findings") raised it. **Four live sessions were on the vendored binary at filing
time, so the removal in "Proposed fix" must not be executed while any are running.** The fix is
small and needs no code change; what is missing is a check that would have noticed.

## Description

Every gate in this repository runs one AILANG. The agent runtime runs another. They are not
the same build, the same version, or the same declared artifact, and the second one is not
tracked in git.

    $ ailang --version                    # PATH — used by `make`, `ailang check`
    AILANG v0.47.2
    Commit: e939cba

    $ ./ailang/bin/ailang --version       # vendored — used by the live agent runtime
    AILANG v0.33.1-85-gde5a141e4-dirty
    Commit: de5a141

**The PATH binary is the declared one.** `ailang.toml:6` sets `ailang = ">=0.47.2"` and
`scripts/install-prerequisites.sh:40` pins `AILANG_REF="v0.47.2"`. The vendored binary is
satisfied by neither.

**It is not tracked.** `.gitignore:16` ignores `/ailang/`, and `git ls-files --error-unmatch
ailang/bin/ailang` fails. The whole `ailang/` checkout — the fork this project vendors and
develops against — is untracked. That is a deliberate choice and is not what this issue is
about. The binary inside it is what this issue is about.

**It is stale against its own checkout.** The binary reports commit `de5a141e4`; the source
beside it is at `2063f4ceb`, which is two commits ahead:

    1280ddc86 fix(openrouter): Muse Spark compatibility — native max_tokens,
                           reasoning_content on replayed tool calls
    2063f4ceb fix(openai): surface in-band SSE stream errors as AIError

Both touch provider adapters only (`internal/ai/openrouter/*`, `internal/ai/openai/*`).
Neither touches AILANG language semantics or `src/core`. The `-dirty` suffix means the binary
also does not match the working tree it was built from; the one modified file there is
`tools/motoko/r8_headroom_band.ail`, a two-line test-fixture change.

So the vendored build is missing exactly the two fixes that make OpenRouter and OpenAI
streaming behave — and EXP-MODEL-03 ran four OpenRouter-hosted models through it.

## How the vendored binary gets selected

The selection is a documented, first-class override, not an accident of path order.

`src/tui/src/config.ts:53` declares it as config:

    "runtime.ailang_bin": { env: "AILANG_BIN" }

`src/tui/src/index.ts:720-721` and `src/tui/src/runtime-process.ts:911-913` resolve it with an
explicit fallback to `"ailang"` on `$PATH`:

    const ailangBin = (process.env.AILANG_BIN && process.env.AILANG_BIN.trim() !== "")
      ? process.env.AILANG_BIN
      : "ailang";

`scripts/run-agent.sh:27,37-39` sets it **only if the file exists**:

    LOCAL_AILANG_BIN="${PROJECT_ROOT}/ailang/bin/ailang"
    if [[ -x "$LOCAL_AILANG_BIN" ]]; then
      export AILANG_BIN="$LOCAL_AILANG_BIN"
    fi

This is why the fix below needs no code change: **deleting the file moves the runtime onto the
binary the repo already declares and installs.** The override is opt-in by design and is
currently opted into by a stale untracked build.

## Why it matters

**A DST verdict is about the driver as one compiler builds it, and the type-check gate is
about another.** `make demo_dst` runs `ailang check` (v0.47.2) against the mutant and then has
the agent run `strict_replay` under the runtime (v0.33.1-dirty). The two are never the same
build, so "the type checker passes but strict_replay fails" is a claim about two compilers.

**The vendored build lacks a cache-validation mechanism the installed one has.** Measured
directly against the fork's own history, not inferred:

    $ git -C ailang show e939cba:internal/pipeline/cache_artifacts.go | grep -c stamp   # 23
    $ git -C ailang show de5a141e4:internal/pipeline/cache_artifacts.go | grep -c stamp  #  0

The `artifactStamp` type, `maxArtifactStampBytes` and the `fileScope == "stamp"` load path are
present in v0.47.2 and entirely absent from the build the runtime uses. Both binaries share
`src/core/.ailang`, so the compiler that gates the mutant and the compiler that runs it use one
cache directory, and only one of them validates what it loads from it. A wrong load was not
demonstrated; nothing in the old binary would stop one.

**Results obtained under the old compiler are not reproducible after removal.** EXP-DST-01
(66 runs), EXP-MODEL-02 and EXP-MODEL-03 (12 runs) were all produced by v0.33.1-dirty. They
should be labelled with the compiler version, and the two OpenRouter/OpenAI fixes mean
OpenRouter-hosted model behaviour may legitimately change.

**A mutant planted in the checkout is compiled as a live driver.** `scripts/run-agent.sh:41-53`
`cd`s to the project root because the runtime reads its own `src/core/*.ail` from the working
tree. Any session started from the main checkout while a mutant is planted runs the mutant as
its real driver. That is the same shared-tree hazard as the isolation review, and removing the
stale binary does not address it.

## Proposed fix

Delete the binary; do not rebuild it. Rebuilding keeps a second, unsanctioned compiler on the
tree, and the problem is its existence rather than its staleness.

Order matters — four sessions were on it at filing time and deletion would kill them mid-run:

1. **Quiesce.** Confirm nothing is executing it:
   `pgrep -af 'ailang/bin/ailang'` must be empty.
2. **Move, do not delete.** `mv ailang/bin/ailang /tmp/ailang-v0.33.1.bak`, so the change is
   reversible in one command.
3. **Verify the fallback.** `env -u AILANG_BIN ailang --version` → `v0.47.2`, then one short
   `make demo_dst` run.
4. **Make it stick.** No code change is needed; `run-agent.sh:37` already no-ops when the file
   is absent. Optionally add a `make check_ailang_single` target that resolves
   `ailang --version` and fails if a second AILANG is reachable under `ailang/bin/`. A guard
   that is never called is a guard that does nothing — see
   `.agent/issues/` history and `tmp/exp03/CORRECTION3.md` §2 for two that were.

## Verification

    $ ailang --version && ./ailang/bin/ailang --version 2>&1
    AILANG v0.47.2
    bash: ./ailang/bin/ailang: No such file or directory

One `ailang --version` on `$PATH`, and the runtime resolves to it.

## Blast radius

`scripts/run-agent.sh` is the only non-test code that names the vendored path. Two archived
spike scripts under `.agent/projects/009_motoko_dst_execution/spike/` reference it in comments
as an `AILANG_BIN=` example, and experiment scripts written during the DST work
(`tmp/exp01/run.sh:36,40`) call it by absolute path — those are scratch files under the
gitignored `tmp/`, and they are pinned to the old binary, which is a second reason to relabel
the results they produced.