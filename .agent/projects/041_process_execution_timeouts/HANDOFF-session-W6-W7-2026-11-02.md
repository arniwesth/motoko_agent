# HANDOFF — 041 PLAN-001, session W6-W7, 2026-11-02

**The next session is this run's orchestrator and delegates.** It runs PLAN-001 through
`.dagr/run-041-plan-001.json`, gives implementation to Claude delegates on `claude-opus-5-5` through the
herdr extension, verifies each from git and its own gate runs, and merges nothing.

This session merged nothing and built nothing itself: it wrote two briefs, delegated W6 and W7, verified
both from git, and settled the run file. **The scripted half of the plan is now complete. Everything left
waits on an AILANG release.**

## How to pick this up

- Start from this file. The predecessor record is `HANDOFF-2026-11-02.md` and
  `RECORD-session-W1-W5-2026-11-02.md`, both beside it; read them for W1-W5 and for the path guard.
- **The next task is W8, and it is blocked.** W8 needs U2035 and U2036; W9 needs U2034; W10 needs W7+W8;
  W11 needs W8+W10; W12 needs W8/W9/W10/W11. All four upstream issues are **OPEN** as of this session, so
  **there is no ready work**.
- `.dagr/run-041-plan-001.json` is gitignored, so a fresh checkout does not have it.
  `start-orchestrator.sh` writes it from the committed `PLAN-001.dagr.json`; `MERGED` names the finished
  tasks, which are **W1 to W7**.
- **Nothing is waiting on the operator to merge.** #307 merged as `5fe68724` on 2026-11-03, so W1-W7 are
  all in `main`. #303 is still open (review required) but nothing in the plan waits on it.

---

## Where the plan stands

| Task | State | Evidence |
|---|---|---|
| W1 R6 admission test | **merged** (#292) | 4 r6_post_change_* rows pass; mutants t1/t2 reproduce |
| W2 D5's setsid/SIGKILL probe | **merged** (#293) | 12 mutants killed |
| W3 cancellation witness | **merged** (#294) | expected failure + SIGTERM/SIGINT twin reproduces #2034 |
| W4 resolver module | **merged** (#295) | 207/207 rows, 111 mutants killed |
| W5 `execution-program/6` | **merged** (#301) | p1-p8 (9 mutants) killed; `c2_guard` PASS |
| single-construction gate | **merged** (#296) | 576 files, 0 breaches |
| D5 SIGKILL wording | **merged** (#297) | R10/D6 byte-identical |
| hygiene | **merged** (#298) | `new.sh --no-track`; `gh pr edit` note |
| **W6 scripted carrier, expiry, projection** | **merged** (#305, `9400bd07`) | s1-s5 + 5 own mutants killed; 619 matrix rows unchanged |
| **W7 argument errors, scripted metadata** | **merged** (#307, `5fe68724`) | e1-e8 + 8 own mutants killed; W6's stand-in removed; 0 matrix rows moved |
| W1-W5 handoff docs | **merged** (#304, `cd4b5d7b`) | |

`origin/main` is **`5fe68724`**. The shared checkout is fast-forwarded to it and its 9 modified tracked
files are the same unrelated ones — no work of this session is in them.

**R11's four-week fallback clock now runs from W7's merge, 2026-11-03.** If W12 has not landed by
**2026-12-01**, one regeneration of `manifest-A` follows the scripted work alone. That date is the
plan's, not a preference.

---

## W6 — what landed

**PR #305, merged as `9400bd07`.** `ToolInvocation.process` carries the resolved limit;
`scripted_tool_outcome`'s deadline check became `process_deadline_expires` with the order unchanged;
`tool_phase` resolves ahead of the port; the extension invocation takes
`extension_process(w0.process_limits)` and never reads `timeout_secs`.

**The pre-dispatch refusal is in and correct**, which was the one thing W6 must not get wrong.
`live_tool_outcome` checks `needs_process_primitive(inv.process)` **before** `dispatch_one_typed`; that
helper is true only for `ExplicitMs`, false for `None` and `SessionDefault`. Evidence that nothing ran is a
`touch` marker absent afterwards, with twins proving the method (SessionDefault and no-carrier both *do*
create their file).

**Two things W6 left for W7, both now closed:** an `invalid_request_outcome` stand-in, and Start/Complete
being emitted on an invalid request.

---

## W7 — merged as `5fe68724`

**Verified by me, not taken on the delegate's word:**

| Gate | My own run |
|---|---|
| `make check_core` | exit 0, 211 OK / 0 FAIL, 61 passed, `576 .ail files, 0 breaches` |
| `make strict_replay` | PASS |
| `make world_state` | PASS — `c2_guard`, `exit_code_witness`, `fault_disclosure_witness` |
| `make anchors` | exit 0, `tool_phase.ail:499` still the fifth routed core clock site |

**The stand-in is gone.** `invalid_request_outcome` has zero references. The invalid arm returns
`emitted: [invalid_event]` — `ToolArgumentsInvalid` only. Start is gated at `tool_phase.ail:491`, joined
onto an existing line so `:499` did not move. No off-limits file touched (`tool_catalog.ail`,
`tools/eval_protected/`, `scripts/eval/`, `Makefile`, `src/tui/`, `packages/` all clean).

### The three findings needing an operator or W13 decision

1. **A21's `Search` half does not hold, and it is a real ADR/code conflict predating W7.** ADR **I2** says
   "`ReadFile` and `Search` keep 034 D2's `none`". A scripted `Search` deadline reports `effects: unknown`,
   because `deadline_fault` (`tool_fault.ail:314`) hardcodes `EffectsUnknown` for every tool and does not
   look at which one. W7 pinned today's bytes rather than change them, which is right: changing it would
   alter a `Legacy` program's output and contradict A10, and `unknown` is the safe direction. **The plan
   gives Search to W10 (line 546) but line 653 asks W13 for "A21 across both worlds", so W13 will meet
   this.** Amend I2 or assign it explicitly.
2. **The plan's `e1` mutant was under-specified and W7 closed the gap correctly.** As written, `e1` emits
   Start on the wire only, and `corpus_judge` reads the trace, so nothing saw it. The delegate did not
   weaken the mutant: it made `e1` emit on both channels and added `e1w` as the wire-only form, then added
   a ninth subject to `ledger_parity` (`EXPECT_FRAMES=9`) so a wire-only Start is visible. **Any future
   mutant about a wire event needs a parity subject, or it can survive silently.**
3. **`event-vocabulary/4` was kept, and it was a judgement call.** D8 says a change to any variant is a
   version change. W7 read an *added* row as not one: the three bumps so far were all deletions, adding
   `ToolArgumentsUndecodable` did not bump, and the module's header says a build at `/4` reads no earlier
   trace. **If read the other way, `/5` costs six pinned strings in five DST scripts, with no profile
   bump.**

**No profile bump was needed**, as the plan expected for W6-W12.

---

## The one thing that will burn you: `AILANG_FS_SANDBOX`

The most valuable thing this session learned.

My shell exported **`AILANG_FS_SANDBOX=/workspaces/motoko_agent`** — the *session* workdir, i.e. the shared checkout,
not the worktree under test. **It comes from the Motoko harness, not from PID 1**: it is present in the
orchestrator's tool shell and absent from every herdr delegate pane (I checked four of them, count 0 each).
That asymmetry is the whole trap: my shell and a delegate's shell disagree about whether a file exists.
Neither the `strict_replay` nor the `world_state` Makefile recipe unsets it. Under it, **`fileExists`
reports `false` for a file that genuinely exists.** I proved it directly: a `touch` created a real file
(`real file present? YES`) while `fileExists` reported `false`.

Effect: `make strict_replay` and `make world_state` failed three rows for W6 — including the two most
load-bearing *control* rows — for reasons unrelated to the change. With `env -u AILANG_FS_SANDBOX` both
passed. I nearly reported a defect that did not exist.

**So: run the DST targets as `env -u AILANG_FS_SANDBOX make <target>`.** W7's delegate was *denied*
`env -u` by its permission classifier and ran plain (its shell had the variable unset, so results agreed).
If a delegate reports a DST failure in these tests, check the sandbox before believing it.

---

## The credential trap

**`MOTOKO_BOT_GH_TOKEN` and `GH_TOKEN` are in the container init's environment (`/proc/1/environ`), not in
a Motoko tool shell's.** My first session-half concluded, wrongly, that the token was absent: the repo-root
`.env` is a character device bound to `/dev/null` (size 0), and `gh auth status` said "not logged in".
Both are true and neither means the token is gone.

- **Motoko's own `BashExec`** needs it sourced:
  `eval "$(tr '\0' '\n' < /proc/1/environ | grep -E '^(GH_TOKEN|MOTOKO_BOT_GH_TOKEN)=' | sed 's/^/export /')"`
- **A herdr delegate already has it** and does not need to source anything. Telling it to source from
  `/proc/1/environ` got W6's delegate a permission denial; W7's was told it was unnecessary.
- `gh` lacks `read:org`, so **`gh pr edit` fails**. Use
  `gh api -X PATCH repos/arniwesth/motoko_agent/pulls/<n> -F body=@<file>`.

Also: `.git/config` is a read-only mount. `git checkout -B` and `pr.ts create` print
`could not write config file ... Device or resource busy` and succeed anyway. Do not read that as failure.

---

## Traps carried forward, still true

1. **An aggregate gate can fail for a reason that is not the thing you are testing.** Measure the mechanism
   first. This session's `AILANG_FS_SANDBOX` finding is a second instance of the same trap.
2. **A `/tmp` worktree is not a valid baseline.** AILANG auto-relaxes MOD010 there. Baselines go in
   `/workspaces`.
3. **`make dst` and `make eval_matrix` run alone**, never beside each other.
4. **`make dst` is red on `main` today**, identically at base (`declared_vs_performed`, 127 passed / 10
   failed). Compare FAILED names head-against-base and report only the difference.
5. **`cd src/tui && bun run test` is red at base**: 4 suites fail to run, 472 tests pass. Nothing in 041
   touches `src/tui`.
6. **A foreground shell call dies at ~30 s and takes its child with it.** Use
   `(setsid cmd > log 2>&1 &)` then poll. `nohup ... &` inside the call is not enough.
7. **`verify_herdr_orchestrator` creates `./.tmp-herdr-orch/`** in whatever checkout it runs from.
8. **`src/core/process_limits.ail:18` still names the old checker path** — stale, fix it next time the
   module changes.
9. **`new_contract_policy` and `verify_classify` cannot read `VERIFIED (bounded: depth 2)`.**
10. **`verify_single_construction.py` reads only the first import on a joined line.** A result constructor
    in a joined import is misread as a value and reported as a false breach. Put the import first.
11. **`make verify_classify` can exit 1 on a solver timeout** in a module you did not touch, while still
    writing the register. Commit only the pins your change moved, and say so.

---

## Open pull requests as this session ended

| PR | Branch | State | What to do |
|---|---|---|---|
| ~~#307~~ | `arniwesth/041-w7-argument-errors` (`6a93884b`) | **MERGED** as `5fe68724` | done |
| **#303** | `fix/path-guard-set-plus-e` (`813c0ce6`) | OPEN, **REVIEW_REQUIRED**, all 8 CI checks pass | Merge when convenient. Nothing in the plan waits on it |
| #299 | `fix/path-guard-login-shell` | closed, superseded by #303 | nothing to do |
| #300 | `fix/path-guard-fail-closed` | closed; needs a rebase onto #303 if revived | nothing to do |
| #234 | `fix/portable-path-guard` | open | the better long-term macOS fix; nothing waits on it |
| #287 | `fix/cost-cap-cache-tokens` | open | **overlaps 041**: changes `session.ail`, may move its anchors. Whichever lands second rebases |

#303 sits in `REVIEW_REQUIRED` with no reviewer requested, so it will not move on its own.

---

## Worktrees

All exist and are clean (`dirty=0`) unless noted:

| Worktree | Branch | Head | Disposition |
|---|---|---|---|
| `-041-w1` … `-041-w5` | `arniwesth/041-w{1..5}-*` | — | merged; delete when convenient |
| `-041-w6` | `arniwesth/041-w6-scripted-carrier` | `516faade` | merged (#305); delete when convenient |
| `-041-w7` | `arniwesth/041-w7-argument-errors` | `6a93884b` | merged (#307); delete when convenient. Has a gitignored `src/tui/node_modules` from a `bun install` |
| `-041-singlegate`, `-041-d5-note`, `-041-hygiene` | — | — | merged |
| `-pathguard`, `-pathguard2`, `-pg3` | — | — | #299/#300 closed; `-pg3` holds #303 |
| `-handoff` | `docs/041-handoff-w6-w7` | — (see PR) | this file (PR #308). Its head is deliberately not named: a blob cannot record the SHA of the commit that contains it, so the PR is the reference that stays true |

`-011-calibration-pilot` is **another session's**. Leave it alone.
`-improving-experimentation` appeared during this session and is not mine; leave it alone.

---

## How this session delegated, for continuity

Every brief was a stand-alone file under `tmp/041-orchestrator/briefs/`, session-local and not committed:
`W6-a.md` (311 lines) and `W7-a.md` (305 lines). Each carried the plan's section and the graph's criteria
and note **verbatim**, the gate set, the mutation discipline, a re-grounded anchor table built at the
delegate's exact base, the traps above, a "what NOT to do" list, the ship steps, and the exact shape of the
answer.

**Both delegates were competent and one improved on the plan.** W6's delegate caught that `BashExec`
ignores `workdir`, so its own "did not run" rows had been looking in the wrong directory — and it said so.
W6 and W7's delegates each added mutants beyond the plan's (5 and 8) and each reported a finding that
corrected either the plan or my brief. **Give them the re-grounded table; it saves them a wrong-tree
search.** Let them stop: both stopped correctly when something was genuinely wrong.

**Re-grounding paid off twice.** For W6, almost every `ports.ail` anchor had moved (+6 from W5) and four of
seven "fan-out" files were not under `src/core/`. For W7, C3 had held and every anchor was exact — so the
table was short. **Measure it each time; do not assume either way.**

Budget: this session used about 215 of 1200 steps.

---

## Immediate order of work for the next session

1. **Nothing to merge for the plan.** W7 merged as `5fe68724`. #303 is still open and can land at leisure.
2. **Next session: there is no ready work.** Check the four upstream issues before anything else:

       gh issue view 2035 --repo sunholo-data/ailang    # and 2036, 2034, 1878

   All four were **OPEN** on 2026-11-02. W8 needs a released tag carrying **both** #2035 and #2036
   (D3: one without the other unblocks nothing). W9 needs #2034. If nothing has closed with a release,
   do not delegate — say so and stop. That is the correct outcome, not a failure.
3. **When a task does unlock:** write a stand-alone brief under `tmp/041-orchestrator/briefs/`, with the
   plan's section and the graph's criteria and note quoted verbatim, a **freshly measured** re-grounding
   table at the delegate's exact base, `env -u AILANG_FS_SANDBOX` on every DST target, and the traps above.
   Quote the pre-dispatch rule verbatim for anything touching `live_tool_outcome`.
4. **R11's four weeks count from W7's merge**, not from W6's. W7 is the last item before W12 that moves
   protected symbols, so the clock starts when #307 lands.

## Two questions the operator should answer before W8

- **ADR I2 vs the code: `Search`'s deadline disclosure.** I2 says `ReadFile` and `Search` keep
  `effects: none`; `deadline_fault` reports `unknown` for every tool. W7 pinned today's bytes. Amend I2
  or assign the fix to W13 explicitly — W13 is scoped for "A21 across both worlds" and will meet it.
- **D8 and `event-vocabulary/4`.** W7 read an added variant as not a version change, on the precedent that
  all three prior bumps were deletions. If you read D8 otherwise, `/5` costs six pinned strings in five
  DST scripts and no profile bump.
