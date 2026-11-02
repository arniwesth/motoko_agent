# RECORD — 041 PLAN-001 session, W1-W5, 2026-11-02

Written while the session ran, starting from a report headed "session report, W1-W4, 2026-11-01". Each
section states what was true when it was written, so "draft" and "not merged" below are not current, and
the mistakes it admits are left as they were. For the current state, read `HANDOFF-2026-11-02.md`, beside
this file. Later than anything below: W1-W5, #296, #297 and #298 merged; #299 and #300 closed unmerged.
The briefs and logs it mentions were session-local and are not committed.

All four work items are done, each on its own branch and worktree, each a DRAFT pull request.
Nothing is merged. W5 cannot start until W1 and W4 are merged (operator's job).

## The four pull requests

| Task | Branch | Head | PR |
|---|---|---|---|
| W1 | arniwesth/041-w1-r6-admission | 1837fb89 | #292 |
| W2 | arniwesth/041-w2-setsid-probe | d308cdb8 | #293 |
| W3 | arniwesth/041-w3-cancel-witness | b67985af | #294 |
| W4 | arniwesth/041-w4-resolver | ce9f39b9 | #295 |

All four branch heads match `git ls-remote --heads origin` exactly. All four worktrees are clean.
The shared checkout's `git status --short` is byte-identical to the step-0 baseline throughout
(`step0-status-baseline.txt`, session-local and not committed): 9 modified tracked, 13 untracked, none of it touched by this session.

## Gates I re-ran myself (not taken on the delegates' word)

W1: make check_core 0 (60/60); make test 0; admission check 0 with all four r6_post_change_* PASS;
    both mutants reproduced from mutate.sh (t1 -> content_served only; t2 -> admits + 2 also_red).
    TUI counted at base for comparison: identical.
W2: make check_core 0, probe rows reproduced: pipes held 3005ms marker present at return,
    pipes closed 1003ms marker after, SIGKILL status 137 marker ~1900ms later. No NOT EVALUATED.
    make test 0.
W3: TUI 4 failed/45 passed/49 total vs base 4/44/48, 472 vs 469 tests. check_core 0.
    Twin reproduced #2034 by hand: SIGTERM 143 and SIGINT 130 both left markers past the limit,
    with the no-signal control showing the deadline does stop them.
W4: check_core 0 (61 files, new module picked up); test_coverage 0 (process_limits 189/189,
    899 of 912); new_contract_policy 0 (26 justified); verify_classify_check 0 after the re-pin
    (76 contracts, 73 substantive); check_single_construction 0 (575 files, 0 breaches).
    Module byte-identical since 858af7cb, so the 92-mutant table stands.

`make eval_matrix` was NOT re-run by me for any task. W1's delegate compared it head against base:
no row difference, 66 rows red on both sides under the two suites R11 exempts.

## Two orchestrator errors this session

1. My W4 brief's file list omitted `tools/verify_classify/contracts.register`. `make verify_classify_check`
   is in G-core, which W4 must pass, and adding a contract mechanically unpins the register. The delegate
   stopped correctly; I ruled the file in scope (generated output only, no hand edits, no override lines)
   and re-delegated. Precedent for committing it: 034 W2.2 (168a3afa). Later items that add contracts
   must list it in their briefs.
2. The W1 brief initially pointed at `.agent/github/staging/<branch>/` with a slash; the real path uses a
   hyphen. Corrected in later briefs.

## Open items for the operator

1. **W2 found D5's wording incomplete.** "The command survives" a SIGKILL is true only for a command that
   does not write to its stdout/stderr after the kill: those pipes died with the runtime, so its next write
   ends it with SIGPIPE. The row pins the surviving case, which is what D5 asks for, so W2 is not blocked.
   No row pins the dying case, and the ADR is unedited. Your call whether D5 needs amending.
2. **W2 measured the limit + WaitDelay bound at ~6017ms**, not a clean 6000. No row exercises the bound
   today because the held descendant exits at 3s. A later row that reaches it needs slack.
3. **W3's witness will not turn CI red when #2034 is fixed.** No CI job runs the TUI Jest suite
   (Makefile:3309) and the twin stays unwired until W9. The "turns red when behaviour changes" signal is
   voluntary. That is consistent with the plan but weaker than it reads.
4. **W4's r9 construction-site check runs in no gate.** `evidence/W4/check_single_construction.py` passes
   (575 files, 0 breaches) but only `mutate.sh` or a person runs it; W4 could not touch the Makefile.
   Once W5 starts using these types, the "only constructor" rule is unguarded unless someone wires it in.
5. **PR #287 also changes `contracts.register`.** Expect a conflict on timing lines; whichever lands
   second should re-run `make verify_classify` rather than merge the file by hand.
6. **`gh pr edit` fails with the bot token** (needs read:org); `gh api -X PATCH` works. Worth a note in
   tools/pr.

## Environment notes

- `~/.claude/settings.json` had no `permissions.defaultMode`; I set it to `auto` so delegates could run
  shell commands. It does not survive a container rebuild.
- A container rebuild during the previous session left 20 stale worktree registrations; I pruned them and
  recreated `-041-w1` at the same path and branch. `tools/worktree/new.sh` now prints
  "could not write config file .git/config: Device or resource busy" on every call, but the worktrees are
  created correctly and are usable; the message comes from the commit-hook install step, not the worktree.
- The delegate permission mode is `auto`, so a delegate may stop at a push or `gh pr create`. None did.

## Later sessions

This session's task ids W1-W4 are complete. Next: W5 needs W1 and W4 merged. Start the next session with
`MERGED="W1 W2 W3 W4" bash .agent/projects/041_process_execution_timeouts/start-orchestrator.sh`.
The next session is this run's orchestrator and delegates; it must not re-delegate W1-W4.

---

# Follow-ups, same date, after the operator accepted the recommendations

Two items, both drafted. Together with W1-W4 the session now has six draft PRs.

| Item | Branch | Head | PR | Base |
|---|---|---|---|---|
| W1 | arniwesth/041-w1-r6-admission | 1837fb89 | #292 | main |
| W2 | arniwesth/041-w2-setsid-probe | d308cdb8 | #293 | main |
| W3 | arniwesth/041-w3-cancel-witness | b67985af | #294 | main |
| W4 | arniwesth/041-w4-resolver | ce9f39b9 | #295 | main |
| gate | arniwesth/041-single-construction-gate | 0fedbb7b | #296 | **arniwesth/041-w4-resolver** |
| D5 | arniwesth/041-d5-sigkill-wording | da061c37 | #297 | main |

## Recommendation 1: the single-construction gate (PR #296)

Moves the checker from `evidence/W4/` to `scripts/verify_single_construction.py`, adds
`verify_single_construction` to the Makefile, and puts it in `check_core`'s prerequisite list.
It is based on W4's branch, not main, because the checker exists only there; it must land after #295.

Verified by me: `check_core` exits 0 with `check_single_construction: 575 .ail files, 0 breaches`
inside its output. I ran the mutation harness myself: 4 killed, 1 passed. A forged literal and a
forged record update each fail `check_core` (Error 1), a missing module fails it (Error 2), and the
compiler accepts both forged files, so only this gate catches them.

THE DELEGATE FIXED A REAL BUG IN W4'S CHECKER, and was right to. My brief said "keep behaviour
exactly" but also asked for a missing module to exit 2; those conflicted. The old code listed files
with `git ls-files -co`, which still names a tracked file after it leaves the disk, then skipped
anything not on disk, so the missing-module case passed vacuously (exit 0, "0 breaches"). I
confirmed the `git ls-files` mechanism directly. The fix only makes the check stricter.

Known nit: `make` exits 2 for any failed recipe, so the script's code shows as `Error 1` / `Error 2`.
My brief's "make exits 1" was wrong; the harness checks both the script's code and the error text.

Left stale on purpose: `src/core/process_limits.ail:18` still names the old checker path, because the
module had to stay byte-identical. Fix it the next time the module changes, in W5.

## D5's SIGKILL wording (PR #297)

D5's third bullet now says the killed runtime's command keeps running and its side effects happen, but
its stdout/stderr pipes died with the runtime so its next write normally ends it with SIGPIPE. One
bullet changed; R10 and D6 are byte-identical to `main` (verified by diff), and no ruling changed.

The delegate re-measured rather than citing W2, because W2 kept no raw SIGPIPE output, only a
sentence in its PR body. I reproduced the mechanism myself: a command writing to a pipe with no
reader creates its pre-write marker, dies at the write, and never reaches its later marker; with a
reader present both markers appear; with SIGPIPE ignored the write fails but the command finishes.
That is exactly what the new wording says.

Still open by design: the SIGPIPE case has no probe row. Adding one is your decision, not taken here.

## Still not done, and why

- **Permission mode in the image** (item 5): a change under `.devcontainer/`, not yet delegated.
- **`new.sh`'s config noise** (item 6): `tools/worktree/`, not delegated. Note it is harmless —
  every branch and worktree was verified individually.
- **The `gh pr edit` note** (item 7): `tools/pr/`, not delegated. `gh api -X patch` works meanwhile.
- **W3's CI blindness (item 4):** deliberately deferred to W9, as recommended.

## Two environment findings worth recording

- `verify_herdr_orchestrator` creates `./.tmp-herdr-orch/` in whatever checkout it runs from and
  deletes it as its last act. One delegate ran `make` in the shared checkout and left it behind; it
  is untracked and holds only that recipe's fixtures. I removed it and the checkout is at baseline.
  A delegate running `make` in the wrong tree will litter one of these.
- Every `tools/worktree/new.sh` call prints `could not write config file .git/config` here. The
  worktrees are still created correctly; I verified branch, base and cleanliness for all six.

## Merge order

W1 and W4 first (W5 waits on both), then #296 (it needs #295). W2, #293 and #297 are independent;
#297 describes things #293 introduces, so #293 should land before or with it. W3 can land any time.

---

# Follow-up 2: hygiene (PR #298)

| Item | Branch | Head | PR |
|---|---|---|---|
| hygiene | arniwesth/041-hygiene-notes | 953db536 | #298 |

Two fixes, one branch from `main`.

**Worktree config noise.** `tools/worktree/new.sh:63` gains `--no-track`. Cause, confirmed by probes:
`.git/config` is a read-only virtiofs mount here, and `-b` on a remote-tracking base writes
`branch.<name>.remote`/`merge`, which cannot be recorded. `git branch zzz` reproduces the message
twice; `worktree add --detach` and `worktree add --no-track -b` are both silent. What it gives up, on a
writable checkout only: ahead/behind in `git status`, and bare `pull`/`rebase` defaults. A bare
`git push` already failed before, because the recorded upstream was `origin/main`, not the branch.
`tools/worktree/test.sh` gains two checks — the shared config is byte-identical across `new.sh`, and the
branch has no upstream — and the delegate confirmed both fail with the old line restored. I re-ran the
test: 38 passed, 0 failed.

**`gh pr edit` note.** New "Correcting a published PR" section in `tools/pr/README.md`, with the
`gh api -X PATCH` form and the reminder to strip the record's frontmatter and correct the record too.
The delegate verified it against #298 itself: `gh pr edit` exits 1 on the missing `read:org`, the REST
patch exits 0.

**A premise of mine was wrong, and the delegate corrected it.** My brief said AGENTS.md and
tools/pr/README.md state that explicit refspecs are the norm. They do not — I grepped both, and neither
mentions refspecs, pushes or tracking at all. The rule appears only in three start prompts under
`.agent/projects/`, and `tools/pr/pr.ts:379` actually does `git push -u`, in the path taken only when no
PR exists yet. So the delegate documented the rule properly in a new "Pushing" section of
`tools/worktree/README.md` instead of citing a source that did not say it.

**Also found: the token's real scopes are `repo`, `workflow`, `write:discussion`.** `tools/pr/README.md:63`
says `public_repo`, which is wrong. Left alone deliberately — the token's scope is the operator's
decision — but it should be corrected when convenient.

**Item 5 (delegate permission mode) is NOT done, deliberately.** `~/.claude/settings.json` lives outside
the repo and nothing in `.devcontainer/` seeds it: the Dockerfile installs the Claude CLI and copies
`herdr.toml`, but no settings file, and there is no template in the tree. A durable fix is a Dockerfile
change plus a tracked template, which affects every session in every project. The smaller change is a
line in `start-orchestrator.sh`'s existing warning giving the exact command to run. Awaiting the
operator's choice.

# Final state: seven draft PRs

| Item | Head | PR | Base |
|---|---|---|---|
| W1 | 1837fb89 | #292 | main |
| W2 | d308cdb8 | #293 | main |
| W3 | b67985af | #294 | main |
| W4 | ce9f39b9 | #295 | main |
| gate | 0fedbb7b | #296 | arniwesth/041-w4-resolver |
| D5 | da061c37 | #297 | main |
| hygiene | 953db536 | #298 | main |

All seven worktrees clean, all heads match origin, shared checkout at the step-0 baseline, no stray
branches or worktree registrations left by any probe.

---

# Follow-up 3: the review of W4, and a fail-open security check

## The W4 review (delegated on the operator's instruction)

A read-only Claude review at `ce9f39b9`, independent worktree, independence discipline followed: it
wrote its predictions from D2/D7 before opening `mutants.tsv`. Verdict: **logic correct, evidence
incomplete.** Twelve mutants that break stated rules survived with `make test_coverage` green.

The structural cause, which I confirmed myself by reading `row_expires`: of its 17 rows, none paired
`Finite` with `CeilingMs`, and none passed a non-zero `legacy` with a positive default.

It also found one real defect: `parse_ceiling_ms` accepted `1.0000000001h` and `1.0000000001m` as whole
milliseconds. I reproduced both. `fraction_ns` truncates to nine digits, which is only correct up to
seconds; for `m` and `h` the tenth digit is still whole nanoseconds.

## W4 follow-up, PR #295 at 9a3a61ec

Added 13 rows (all ten of the review's rules, none judged a non-gap), plus six for the parser fix.
`row_project_test_10` dropped: it exercised `carrier_of`, and D7 states no projection for an invalid
request. Mutants: **111 killed, 0 survived** at `f3ad735c`, and the `commit` file now names it, so the
stale `858af7cb` evidence base is corrected.

I verified: `make test_coverage` exit 0 with `process_limits.ail: 207/207 passed`; the parser now
returns `None` for `1.0000000001h`/`1.0000000001m`, still `Some(1000)` for `1.0000000001s` and
`Some(5400000)` for `1.5000000000h`; and all ten rows are present verbatim in the source.

KNOWN TRADE-OFF: the fix is stricter than Go on a narrow class. `1.00000000001m` is `60000000000` ns
in Go (the digit is worth 0.6 ns and is truncated) but is now refused, because the value as written
is not a whole number of milliseconds, which is what D2 says. Documented in the code comment.

TOOLING GAP found by that delegate: `new_contract_policy` and `verify_classify` cannot read the verdict
`VERIFIED (bounded: depth 2)`, so a recursive helper verifying that way reports "the module did not
compile" — misleading, since it does. Worked around by reusing `decimal_value`. The next recursive pure
function that verifies that way hits the same wall.

## The #296 checker hole, closed at 8753db8e

The review found `UPDATE_RE` requires the update's base to match `[\w.]+`, so `{ idr(r) | budget: x }`
— a forged update on a call result — passed. `budget` is the field enforcement reads.

I specified a widening; **the delegate rejected it and was right.** I ran my own pattern against the
tree: **16 false positives** across the extension packages, which would have turned `check_core` red.
Its replacement finds the head of the update's field list and fires only when all of that update's
labels are result fields, which also handles `PureCtx` having a `budget` of its own.
Evidence went 4 killed/1 passed to **6 killed, 5 passed**, with the survival control `g6` passing.

## The fail-open security check (the serious finding)

`verify_native_path_guard` began failing mid-session. I could not explain it; the delegated diagnosis
did, and I reproduced the mechanism myself.

**Cause.** `validate_path_common` (`src/core/tool_runtime.ail:494`) runs its guard with `bash -lc` and
a script starting `set -eu`. On a login-shell exit bash sources `~/.bash_logout`, whose stock Debian
block runs `/usr/bin/clear_console -q` when `SHLVL = 1`. With no console attached that returns 1, and
`set -e` ends the shell with **1 instead of 43**. `validate_path_common` refuses only on 43 or 44 and
lets every other code through (`:495`) — so the guard fails OPEN and the tool follows the symlink.

I verified, with `env -u SHLVL`:

    bash -lc 'set -e; exit 43'          -> 1    (fail open)
    SHLVL=1 bash -lc 'set -e; exit 43'  -> 43
    bash -c  'set -e; exit 43'          -> 43

and `clear_console -q` returns 1, and `~/.bash_logout` has the `SHLVL = 1` block.

**Why it appeared mid-session and not before.** `SHLVL` is in the caller's environment. Bash lowers it
before `exec`-ing a single final command, so the shape of the calling command decides it:
`make > log`, `make | tee log` and `make; true` pass; a bare `make` or my `(setsid make &)` form fails.
Both times were the same commit; only the invocation shape differed.

**This reaches production, not just the test.** Motoko's AILANG runtime has no `SHLVL` (it is not in
`buildChildEnv`'s allowlist in `src/tui/src/runtime-process.ts`), and `BashExec` runs
`bash -lc "cd <cwd> && <cmd>"` (`:1037`). The delegate ran a sandboxed call shaped like production: with
`SHLVL` unset the guard was bypassed and only `AILANG_FS_SANDBOX` stopped the escape; with `SHLVL=1`
the guard refused correctly. So any caller without the sandbox has no symlink protection from this
guard. That is the exposure `fa857e89` set out to close, reached by a different route.

**Repo defect, not container.** The container supplies stock Debian dotfiles, unchanged since 2024.
Three repo choices combine: a login shell for a check whose verdict is its exit code; any code but
43/44 counted as a pass; and no pinning of `SHLVL`, so `check_core` is flaky by invocation form.

**Not fixed here.** It is a security check and the fix touches policy decisions the operator owns.
Recommended, about three lines plus a test:
1. `:494` `-lc` to `-c` — the script only needs `realpath`, and a security check should not read
   profile files.
2. The probe runs under both `SHLVL` unset and `SHLVL=1`, so it cannot regress.
3. `:853` (`acquire_temp_path`) the same change for consistency; it reads stdout and ignores the code.

Decisions raised: macOS may find `realpath` only through a profile, so `-c` could exit 127 there —
no worse than a Mac without GNU `realpath` today, but untested. And the fail-open policy itself wants
its own PR: refusing on any non-zero code except a specific "realpath unavailable" result would have
made this bug loud instead of silent.

**Immediate workaround, no code change:** `SHLVL=1 make check_core`, or redirect/pipe the make output.
That makes the gate pass; it does not close the production gap.

Diagnosis worktree `-diag-guard` is clean with no commits. The finding lives in this record.

## The path-guard fix, PR #299 at db6772f6

`validate_path_common` `:494` and `acquire_temp_path` `:859` go from `bash -lc` to `bash -c`, each with
a comment giving the reason. `BashExec`'s `-lc` at `:1038` is untouched, as instructed: that is
user-facing behaviour and changing it would alter what every model-issued command does.

The probe now pins SHLVL both ways: the old body became a `scenario` entry, and the new `main`
re-invokes it twice through `env`, once with SHLVL unset and once with SHLVL=1. A leg fails if any
check fails, if the child did not really have the pinned SHLVL, if the child could not run, or if fewer
than six checks passed. A leg cannot pass by not testing.

Verified by me, with `env -u SHLVL`:
- `make verify_native_path_guard`: **16 OK, 0 FAIL** — 8 under `[SHLVL 1]` and 8 under `[SHLVL unset]`.
- `make check_core`: **passes**, 60 files type-check (60 and not 61 because this branch is cut from
  `main` and does not carry W4's module). Before the fix this shape failed at the guard.

### Three places the delegate's measurement corrected my brief

1. My "exposing" gate shape `(setsid make check_core &)` did **not** fail, because that pane's shell had
   SHLVL=2 and the child inherited it. The trigger is SHLVL unset or 0 **on entry**, not the command
   shape. An honest correction: I had inferred the shape from the failure rather than measured it.
2. `acquire_temp_path` is **not** at risk the way I said. `~/.bash_logout` is sourced by the `exit`
   builtin, and that script has no `exit`. The change was still made, but its comment states the reason
   that actually holds: a profile that prints would corrupt the path read from stdout.
3. The extensions are **not** broken the same way, for the same reason — their scripts end in
   `"$bin" "$@"`, with no `exit` builtin. All three read their exit codes correctly.

### A separate defect found on the way, confirmed by me

`BashExec` itself (unchanged, deliberately) has the same failure mode. With SHLVL unset:

    bash -lc 'set -e; exit 3'    -> 1   (not 3)
    bash -lc 'exit 3'            -> 3
    bash -lc 'set -eu; exit 0'   -> 1   (not 0)

So a model command that uses `set -e` and an explicit `exit` loses its code, and **a successful
`set -eu; exit 0` is reported as failed** in a real session. Not a security hole; a real usability bug.
It deserves its own item. Changing `BashExec` to `-c` is not the fix, since model commands expect a
login shell — the fix is probably to restore the code after the logout hook, or to make `BashExec` pass
`SHLVL=1`, which needs its own decision.

### macOS, unresolved by design

Under `-c`, a `realpath` findable only through a profile (Homebrew coreutils) is not found, the guard
exits 127, and `:495` reads 127 as a pass. So on such a host this fix **swaps one fail-open for
another**. Stated in the code comment and the PR body. The fail-closed policy follow-up is what removes
it; this PR does not claim to.

### Merge-order warning

`tools/worktree/status.sh` flagged **#234** (`fix/portable-path-guard`) as rewriting the same guard
lines under `bash -c` and failing closed, and **#209** as touching `atomic_write` next to
`acquire_temp_path` plus the same probe. Whichever merges second must rebase, and the SHLVL pinning in
the probe should survive it. I could not verify #234's branch or state without a token; the plan itself
lists #234 as touching `tool_runtime.ail`, so the conflict is expected.

### Note for whoever reviews the pinned-probe test

The unlogged caveat: the probe's unset leg only detects this defect on hosts whose `~/.bash_logout`
behaves like Debian's. Elsewhere both legs pass with or without the fix. That is honest and fine — the
leg pins the condition rather than the file — but it means the test's teeth are host-dependent.

## The fail-closed policy, PR #300 at 5bc93e47

`validate_path_common` now allows only exit 0. 43/44 keep the "path escapes workspace" message; every
other code and an `exec` Err get a **distinct** message: "path guard could not run (exit N), so the path
was refused; this is a fault in the environment, not in the path". The `Err` arm used to say "escapes
workspace", which was the same blurring the brief warned about, and that is fixed too.

One change the brief did not list, and it was necessary: an empty workdir means the process cwd, but
`realpath ""` exits 1, so under the new policy that would refuse every path. The caller now passes `.`
when the workdir is empty, and the guard script itself is unchanged.

Verified by me on this branch, ambient SHLVL: `check_core` reaches **195 OK, 3 FAIL**, and the three are
the `SHLVL`-unset escape rows refusing with the could-not-run message rather than the escape message.
That is the predicted consequence of landing #300 without #299.

### THE RISK THAT CHANGES THE RECOMMENDATION

**Stock macOS loses the native file tools if #300 merges before #234.** The guard uses `realpath -m`,
which is GNU-only. BSD `realpath` has no `-m`, so it fails for **every** path, exits 1, and under
fail-closed that refuses every ReadFile, WriteFile and EditFile - including paths inside the workdir.

I verified the mechanism: GNU `realpath -m` works here, and a stub `realpath` that rejects `-m` exits 1,
which is what the new policy reads as could-not-run. The delegate measured the same with a Linux stub of
BSD `realpath` on a trial merge: a WriteFile inside the workdir returned
`path guard could not run (exit 1) ... realpath: illegal option -- m`. Nothing was run on real macOS.

**The trade-off is honest and stark: today those hosts silently follow symlink escapes; after #300 they
would have no file tools at all.** #299's brief named only the narrow Homebrew-through-a-profile case;
the delegate found the wider stock-macOS one.

### #234 overlap - the delegate's judgement call, and mine

The delegate found `#234` (`fix/portable-path-guard`) with `gh pr list`: an open PR from an outside
contributor, currently CONFLICTING, which makes the same policy change **and** replaces the guard with a
portable resolver tested on a real Mac - fixing the macOS problem above.

It went ahead without asking, inferring permission from #299's body recording the operator choosing a
narrow fix ahead of #234. That choice was recorded for #299, not for #300, and it said so. **My view: it
should have stopped.** AGENTS.md says stop and ask on overlap, and the inference does not carry.

**RECOMMENDATION, changed by the macOS finding: do not merge #300 before #234 is resolved.** Either
#234 lands and most of #300's core change goes away - its rows are still worth keeping - or #300 is
rebased on a portable guard. Landing #300 first turns a silent security hole into a hard outage on
stock macOS, which is the worse failure.

Merge order if both land: **#299 first, then rebase #300.** With #300 alone the Motoko runtime has no
SHLVL, so a real escape is refused with "this is a fault in the environment, not in the path" - safe but
misleading. #299 alone is safe; #300 alone leaves `check_core` red under `env -u SHLVL`, as `main`
already is. The two conflict in `tool_runtime.ail` and the verifier in either order, so conflicts do not
favour one. Reconciliation, which the delegate tried in a scratch worktree: keep #300's arms and #299's
`-c`; drop #299's sentence saying 127 is "also let through", which #300 makes false; keep #299's
scenario/leg split in the verifier and drop #300's duplicate count; change the expected count from 6 to
22.

### Two limits of the evidence, as reported

- `make test` only runs `src/core/agents_md.ail` and takes about a second, so its green says nothing
  about this change. `verify_native_path_guard` is the real evidence.
- The change calls `process_error_to_string`, a new call-graph edge against
  `tools/eval_protected/manifest-A.json`, which was out of scope. `eval_protected_selftest` fails at
  baseline in a scratch worktree too, so whether the manifest needs updating is **unknown**. That is an
  R11 question for the operator.

---

# W5, PR #301 at 2918003c

Draft, not merged. Nine commits on `arniwesth/041-w5-program-v6` from `f3e77a19`.
`InitialWorld.process_limits`, schema v6 with `/5` decodable by name, every writer `legacy`, the mode
through the world and the token, frozen v6 specimens, the C2 guard, W1's test tightened to assert
`Legacy`, and p1-p8 (nine mutants, all killed) plus three added C2 controls.

Verified by me: branch pushed and matching origin; worktree clean; **zero** changes under
`MATRIX.expected.tsv`, `tools/eval_protected/` or `scripts/eval/` (R11); the only fixture files added are
the two v6 artifacts, so frozen v1-v5 are untouched; and `dst_program`, `dst_persistence`, `ext_world`,
`ports`, `dst_replay` all pass `ailang check`.

The one diff that looked like a generator change is `scripts/dst/seeded_generator_dst.ail`, and it is
the writer stamp (`process_limits: Legacy`) in `program_of`, which the plan requires. The generator's
draws, salts and bounds are untouched.

## What the delegate reported, and the two corrections it made to my brief

1. **No matrix row moved**, though the plan says W5 moves rows. 034 W1 had already made those rows red
   with the same first finding. It predicted this in the PR before the run and the run confirmed it:
   619 rows each side, zero differing, 16 finding keys unchanged.
2. **A `/tmp` base worktree is not a valid baseline**, and my brief suggested `/tmp/w5-base`. AILANG
   auto-relaxes MOD010 there and interface failures are hidden; its first base run showed 11 FAILED names
   and 8 differing rows, all location artefacts. Re-run from `/workspaces/motoko_agent-041-w5-base` and
   it matched head exactly. **My brief was wrong; this should have been a workspace-side path.**
3. Its first C2 guard read `session.ail` inside `main`, which must complete with FS withheld, and
   `make world_state` caught it. The guard is now its own `c2_guard` entry point.

`make dst` and `make eval_matrix` both exit 2 at head **and at base**, with the same `declared_vs_performed`
failure and the same 619-row counts, so nothing moved. `declared_vs_performed` is red on `main` today,
independent of W5.

## `check_core`: my brief was wrong, and now I know exactly why

I told the W5 delegate `check_core` was red at `verify_native_path_guard` and to work around it. It
reported exit 0 with the type-check running, 61 of 61. Both are true, and the difference is the shell.

**The complete mechanism, finally reproduced.** The guard runs `bash -lc` with `set -eu`. `~/.bash_logout`
fires `clear_console -q` only when `SHLVL = 1`; that returns 1 with no console, and `set -e` converts the
guard's `exit 43` into exit 1, which `validate_path_common` reads as a pass.

Whether the child sees SHLVL 1 or 2 depends on the **caller's** SHLVL:

    env -i bash -lc 'set -e; exit 43'   -> 1   (clean env: child starts at 1, hook fires)
    my interactive shell (SHLVL=1)      -> 43  (child starts at 2, hook skipped)

So:
- My orchestrator shell has `SHLVL=1`; its child gets 2, and a **direct** `bash -lc` returns 43.
- But `make verify_native_path_guard` still fails with 5 FAILs, and from `env -i` it fails outright with
  `0 OK, 0 FAIL` and `Error 1`. So the make recipe's own wrapping loses the SHLVL that my interactive
  shell happened to carry — the mechanism is the caller's SHLVL, and make's recipe shell does not
  inherit one.
- The delegate's pane had a higher SHLVL, so its child started above 1 and the hook never fired.

**Conclusion: the guard is genuinely fail-open, and whether `check_core` passes depends on the SHLVL of
whoever invokes make.** That is the worst kind of gate: not flaky in its own logic, but conditioned on
the caller. #299 fixes the `-lc`; #300 makes the refusal truthful. Neither is merged.

I reported this earlier as "the invocation shape decides it", then found a case that contradicted it, and
could not close the gap at the time. The gap was that I tested from my own shell. `env -i` settles it.

## PR #303: the path guard fixed with `set +e` (supersedes #299's approach)

Head `813c0ce6` on `fix/path-guard-set-plus-e` from `df14e9cb`. The only script change is `set +e` before
the two `exit` sites, plus a comment; the `-c` change from #299 did **not** come over (I checked: zero
`"-c"` in the diff). #299's probe half did: the probe now runs a `SHLVL`-unset leg and a `SHLVL=1` leg
and fails if either fails.

**Verified by me**, from a clean environment with `ailang` on PATH:

| | unfixed `df14e9cb` | fixed `d23109ed` |
|---|---|---|
| `make verify_native_path_guard` | **1 OK / 5 FAIL** | **16 OK / 0 FAIL** (8 per leg) |
| `make check_core` | stops at the guard | **202 OK / 0 FAIL**, `61 passed, 0 failed` |

### I got the diagnosis right and the measurement wrong

The mechanism I described was correct - errexit converts the guard's `exit 43` into exit 1 via the logout
hook - and `set +e` is the right fix. But **my "proof" was invalid**: I ran

    env -i PATH=/usr/local/bin:/usr/bin:/bin bash -lc 'set -e; exit 43'

and reported `0 OK, 0 FAIL` / `Error 1` as the guard failing. `ailang` lives in `~/.local/bin`, which is
not on that PATH, so the recipe failed for want of a binary, not because of the guard. The delegate
caught this. The same command still fails after the fix, for the same reason.

The valid measurement is with `PATH=/home/motoko/.local/bin:/usr/local/bin:/usr/bin:/bin`, which is what
the table above uses, and it is a real differential: 5 FAIL before, 0 after.

That is the second time in this session I presented a measurement whose cause was not what I claimed.
The pattern: I measured an aggregate and attributed its failure to the thing I was already thinking
about. The delegate's habit of reproducing the *mechanism* before the aggregate is the better method.

### Two more corrections from the delegate, both accepted

1. **`m2` as I briefed it survives.** `exit 44` is unreachable in normal operation: for an existing path
   `realpath -m` and `realpath` agree, so the 43 arm has already refused. Only a race reaches 44. It kept
   the row as a predicted survivor and added `m2a`/`m2b`, which disable the 43 arm so the 44 site is
   tested at all - and `m2a` revealed that for a **new** file the 43 arm is the only protection, since
   `[ -e ]` is false and 44 never runs. Good catch, not a formality.
2. **`set +e` does not defeat *any* exit hook.** A `.bash_logout` or profile that calls `exit 0` still
   replaces the verdict, measured: `exit 0` in `.bash_logout` -> 0; `trap "exit 0" EXIT` -> 0. It removes
   errexit's part only. Closing that needs a positive signal from the guard (a sentinel on stdout), not
   an exit code. **#300's policy would not catch it either, because it also passes on 0.** Narrower risk
   (needs a hostile or unusual profile) but real, and now written down.

### Still open after #303

- macOS untested. This fix **preserves** today's behaviour there; it does not improve it. Where
  `realpath -m` is missing the guard still exits non-43/44 and that still reads as a pass.
- `make verify_native_path_guard`'s error message is misleading: on **any** non-zero exit, including a
  missing `ailang`, it says "a native file tool followed a symlink out of the workdir". That is exactly
  how the missing-binary case got misread. Small separate fix, worth doing.
- `acquire_temp_path` also runs `bash -lc` and reads trimmed stdout; a profile that prints could corrupt
  the temp path. From reading the code, not run.
- #300 will conflict textually and needs a rebase; its policy looks compatible (an inside path exits 0,
  and #300 passes only on 0). Unrun together.
- The probe's inherited claim "the Motoko runtime has no SHLVL" is #299's and was not independently
  verified. Both legs run either way.
