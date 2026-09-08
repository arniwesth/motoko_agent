# 2026-08-11 CI: every PR red, three independent root causes

## Context

Branch: `arniwesth/mot-93-fix-ci`. Pin **v0.33.0**. Entry point was a one-line report — *"All
recent PRs for Motoko fail CI, see e.g. PR #151"* — with no failing target named and no log
attached.

Two commits came out of it, both authored mid-session by the operator from changes made here:

```text
006cea7  Fixed CI issue    Makefile, scripts/install-prerequisites.sh, .github/workflows/dst-corpora.yml   +30
021481b  2. CI fix         .github/workflows/dst-corpora.yml, src/core/prompts_test.ail,
                           tools/test_coverage/{derive.py,skip_reasons.json,
                           fixtures/named_only.ail, fixtures/skip_recorded.ail}         +160 -57
```

Plus one artifact that does not live in this repo:

```text
upstream filing fb_aa130315430290be    AILANG named-test defects, queued 2026-08-11T15:43:27Z
```

**Three root causes, independent of each other, none of them caused by any PR's own changes.** All
three were pre-existing and none had ever passed: each broke on the first day the target that
exercises it was wired into CI. `git status` at close is clean apart from the four `.motoko/config`
files and `ailang.lock`, none of which this session edited.

## The headline

`main` is at `e48de909` and the working branch is **705 commits ahead**. The nightly
`verify-extensions` on `main` has been green every night for a month because it is testing a
month-old tree. **That green nightly was not evidence about the current code**, and reading it as
such is what let three broken gates sit unnoticed. Relatedly, `dst-corpora`'s scheduled job has
fired **zero** times ever (`total scheduled runs: 0`) — GitHub runs `schedule` only from the default
branch, and that workflow is not on `main`.

## Root cause 1 — `smoke_driver` depended on a target that runs after it

`make smoke_driver` runs `scripts/smoke_v2_dp7_gate.ail`, which needs three `/tmp` fixture workdirs
to tell DP7's three outcomes apart (always-fail `check_core`, always-pass, no-Makefile). They are
created by `scripts/setup_dp7_smoke_workdirs.sh`, whose only caller was
`scripts/dst/phase_a_event_parity.sh`, reached only via `make smoke_parity` — **CI step 12, after
the DST gates at step 10**.

So the target passed on any developer machine where an earlier `make smoke_parity` had left the
directories behind, and failed in CI every time since `61f38db` (WI-A16) wired it in.

Why case 3 could not self-heal, which is the part worth keeping. `run_dp7_verifier`
(`src/core/session.ail:1766`) runs:

```
bash -c 'cd "$1" && <command> 2>&1'
```

When the workdir is missing, bash's own `cd:` error goes to **bash's** stderr, outside the inner
`2>&1` that only covers the command. `out.stdout` is therefore empty,
`is_missing_infrastructure("")` is false, and DP7 rejects instead of failing open — visible on the
wire as `dp7_verifier_rejected` with `"errors":""`. The fixture directory has to exist for the
fail-open path to be reachable at all. `setup_dp7_smoke_workdirs.sh` already carried a comment
recording this from a previous encounter.

**Fix:** `smoke_driver` makes its own fixtures. A target whose result depends on what ran before it
is not a gate.

**Verified:** reproduced locally, then confirmed **green in CI** on `006cea7` — `DST AILANG gates`
success, 405 s. Steps 11 (`DST seeded gate`) and 12 (`smoke_parity`) pass as a consequence; neither
had ever executed.

## Root cause 2 — AILANG v0.33.0 implemented named test blocks, and broke them

Step 13 `test_coverage` had **never run in CI**: step 10 always died first, so it was skipped on
every PR since WI-A17 added it. Fixing root cause 1 exposed it.

v0.26.0 parsed `test "name" { ... }` and skipped every one while printing `All tests passed!` and
exiting 0. v0.33.0 runs them, by lifting each body into a synthetic module — visible as MOD010
warnings naming `_namedtest_body_<hash>`. That lifted module loses two different things, and
separating them is what decided the repair:

| Defect | Symptom | Trigger | In-file workaround |
|---|---|---|---|
| 1 | `EVA002: module not compiled: $builtin` | file whose **only** tests are named blocks | add any `tests [...]` block |
| 2 | `LDR001: module not found: src/core/prompts` | any `module_prefix` project | **none** |

Defect 1, measured on a minimal pair differing only by one `tests [...]` block:

```text
named_only_repro.ail        1 passed, 2 FAILED
  pass | 1 + 1 == 2
  FAIL | not false               -> $builtin.not_Bool     EVA002
  FAIL | startsWith("abc","ab")  -> $builtin._str_startsWith EVA002

with_tests_block_repro.ail  4 passed, 0 failed   (identical named tests)
```

`not` is a builtin, so the usable surface in a named-test-only file is just what the evaluator folds
inline — integer arithmetic and comparison on literals.

Defect 2 was isolated with two throwaway probes in `src/core/` (both deleted): LDR001 fires
identically **with and without** a `tests [...]` block, so it is not the same bug and has no
workaround. A flat two-file layout does not reproduce it, which points at the lifted module
resolving relative to its own synthetic location rather than the project root.

**Repairs, and why each is shaped the way it is:**

- `src/core/prompts_test.ail` hit defect 2, so it could not be worked around in place. Converted to
  the wrapper + `tests [...]` idiom `src/core/parse_test.ail` already uses; six assertions preserved
  one for one, **6/6 passing**, six tests recovered that had been dead since they were written.
- `fixtures/named_only.ail` hit defect 1, but must stay named-test-**only** — that is the entire
  thing mutant M12 checks. Bodies are now bare arithmetic, the only expressions that run in that
  state.
- `fixtures/skip_recorded.ail` needed attention nobody asked for. Its four named tests now *pass*,
  so it had no skip left and would have survived **vacuously** — still green, no longer testing
  anything. It now skips via `no generator for parameter`, which is deterministic (no draw makes an
  `Option[string]` generator appear), so it cannot flake green. Quantities: total 8, passed 7,
  failed 0, skipped 1.
- `derive.py` `SELFTEST_RECORDS` repointed at the same reason.
- `skip_reasons.json`: the `Named test blocks not yet implemented` record went stale exactly as its
  own disposition predicted, and was retired into a `_retired` note rather than deleted silently.
  That disposition had refused the `tests [...]` rewrite on the grounds that it would hide an
  unimplemented form; the form is implemented now and `named_only.ail` keeps it covered, so the
  objection expired.

**Verified:** `test_coverage` **420/424 passed, 4 skipped, 0 findings** (was 414 passed and 2
findings); self-test **0 failures**; `mutants.py` **14 mutants, 0 escapes**, M12 still names
`named_only.ail`; `check_core` 57 passed 0 failed.

**Filed upstream:** `fb_aa130315430290be`, both minimal reproductions plus the flat-layout negative
case that localises defect 2.

## Root cause 3 — `ailang.lock` records absolute paths

`pr-corpus` failed in **0 seconds with exit code 2 on every run since 2026-08-04**, its first day.
Never once passed. The log, once readable:

```text
Error: module loading error: failed to load pkg/sunholo/motoko_ext_abi/types:
  package directory not found: /workspaces/motoko_agent/packages/motoko-ext-abi
```

`/workspaces/motoko_agent` is **this dev container's path**. The runner's workspace is
`/home/runner/work/motoko_agent/motoko_agent`. The committed `ailang.lock` hardcodes **19** absolute
paths — the checkout of whoever last ran `ailang lock`. On a runner none of those directories exist
and `ailang run` dies before executing a line.

`verify-extensions` is immune because `make CI=1 sync_packages` runs `ailang lock`, which rewrites
the paths to the current checkout, before anything uses them. `dst-corpora` never hydrated.

**Reproduced** by `sed`-ing the lock in a throwaway clone to the runner's workspace path: identical
error, identical instant exit. **Fix verified** in that same clone: `make CI=1 sync_packages` →
lock repointed → `make corpus_pr` exit 0.

**Fix:** hydrate step added to both `dst-corpora` jobs. `scheduled-corpus` carried the same latent
bug and would have hit it on its first real execution.

## Method note — why this took six wrong hypotheses

Every hypothesis below was tested and killed by measurement, not argument:

| Hypothesis | Killed by |
|---|---|
| `~/.local/bin` not on PATH via `$GITHUB_PATH` | added `Confirm ailang is on PATH` step — **passed**, then `make corpus_pr` still died |
| cold `~/.ailang` registry cache | ran with `HOME` pointed at an empty dir — passed |
| `dash` vs `bash` in make recipes | `/bin/sh` is `dash` here too |
| missing `OPENROUTER_API_KEY` | ran with all provider keys unset — passed |
| un-hydrated `.packages/` | pristine clone had none — passed |
| dev-build gap vs the released tag | local ailang is `ae36986`, **0 commits** after `v0.33.0` |
| Makefile drift on the PR head | fetched raw from the PR head — byte-identical |

**The pristine-clone test was not pristine.** It was cloned to a different path, but the lock inside
it still pointed at `/workspaces/motoko_agent` — which exists here and *is* the repo — so the baked
paths were accidentally correct no matter where the clone ran from. That single unnoticed inheritance
is what made six consecutive hypotheses die and the seventh only findable from the log. The bug is
structurally invisible on any machine whose checkout sits at the baked path.

The PATH change was kept even though its hypothesis was wrong: `install-prerequisites.sh` genuinely
did not export through `$GITHUB_PATH`, the export is correct, and the `Confirm ailang is on PATH`
step is what converted "exit code 2" into a legible answer on the next run.

Reading the logs required installing `gh` (2.97.0 → `~/.local/bin/gh`, arm64 release tarball) and a
**fine-grained** PAT scoped to `motoko_agent` with `Actions: Read-only` — the classic OAuth flow
`gh auth login --web` demands `repo`, which is all-or-nothing across every private and org
repository. `gh auth login --with-token` hangs under the non-interactive `!` shell; the token was
passed per-command as `GH_TOKEN=$(cat ~/.gh_token)` instead, keeping it out of the transcript.

## Open, and deliberately not acted on

**The cost ceiling is now tight.** With a cold compile cache — which CI always has, and which
`ailang lock` guarantees by invalidating it — `corpus_pr` measured **70000 ms against its declared
ceiling of 80000 ms**. The warm-cache measurement was 32000 ms. `dst_corpus.ail:394` sets that
ceiling deliberately from the slow end and its comment warns that a ceiling met and then raised is
the failure mode, so it was left alone. If the next run goes red, that is a measurement to act on,
not a flake to retry.

**Absolute paths in `ailang.lock` are the real landmine and only the symptom is fixed.**
Regenerating in CI works, but a committed lock naming one developer's directory breaks or churns for
anyone whose checkout is elsewhere — it is also why `ailang.lock` shows as modified in the tree
right now. The clean fix is for AILANG to store `path` deps relative to the project root. **Not
filed** — offered, not yet taken up.

**Node 20 deprecation** warnings on `actions/checkout@v4` and `actions/setup-go@v5` appear in every
job. Observed, not acted on.

**Not verified in CI:** root causes 2 and 3 are verified locally only. Only root cause 1 has a green
CI run behind it (`006cea7`). `021481b` had not been through CI when this note was written.
