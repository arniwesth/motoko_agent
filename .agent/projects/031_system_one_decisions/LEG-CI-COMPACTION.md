# LEG-CI-COMPACTION — `compaction_dst` hangs in CI (>20 min against 59 s cold locally)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). This task is **outside 031's line R**, which is
complete. It is a CI defect on 013's DST surface, handed over because it is the last thing between PR 186
and a clean `DST gates (rest)` job. You do not edit the ADR or PLAN-001, you do not write the dagr run
file, and you do not touch other panes or worktrees.

## The failure

CI run **`36010382877`**, job **`DST gates (rest)`**, at `6f96b854` on `arniwesth/031-abi-8-0`.

Step 4 `compaction_dst` started `14:08:56Z` and was **still running past 20 minutes**, with every later
step (`conformance`, `phase_c_l1`, … `smoke_driver`) `pending` behind it. The job dies on
`timeout-minutes: 20` and reports as *cancelled*, which is why this looked like a job-level timeout for
weeks rather than one target.

**Locally the same target is `rc=0` in 59 s cold.** The other DST job (`DST gates (heavy)`) comes in at the
expected ~1.29x of its local time on the same runner image, so this is not "CI is slow" — a 59 s target
does not become a 20-minute one by a 1.3x factor. **Treat it as a block, not as slowness**, until you have
evidence otherwise.

This is **not new and not caused by ABI 8.0**: the pre-split single-step job died in the same place at
`2f3ee4d1`, before line R (run `35505033481`, 25 min).

## What the target is

`Makefile:2447`, five `ailang run` invocations in sequence:

```
compaction_dst:
	ailang run --caps IO --entry main scripts/dst/compaction_policy_dst.ail
	ailang run --caps IO,Env,FS --entry main scripts/dst/compaction_catalog_dst.ail
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main scripts/dst/runtime_status_tool_dst.ail < /dev/null
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main scripts/dst/scripted_cursor_probe.ail < /dev/null
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main \
	  scripts/dst/long_qwen_compaction_dst.ail < /dev/null
```

**Your first job is the same move that named this target: split those five.** One CI step per script, each
with its own `timeout-minutes` (or a `timeout 120` wrapper so the step fails fast with a signature instead
of burning the job's budget). Name the script, then fix it. Do not guess which one from reading alone —
the last three already carry `< /dev/null`, which means someone has been here before and fixed *a* stdin
hang, not necessarily *this* one.

## Hypotheses, in the order I would test them — none verified, all yours to confirm or kill

1. **Blocking on stdin.** The first two invocations (`compaction_policy_dst`, `compaction_catalog_dst`) have
   **no `< /dev/null`**, unlike the other three. A read on an inherited stdin behaves differently under a CI
   runner than under an interactive shell. Cheapest to test, cheapest to fix — but confirm it is the
   *actual* hang before shipping the redirect, or you will paper over a different one.
2. **Network.** Three invocations carry `Net` with `--ai-stub`. If anything reaches the network despite the
   stub, a CI egress that blackholes (rather than refuses) a connection hangs until a timeout that may be
   far longer than 20 minutes. Look for a real connect attempt, not just the capability grant.
3. **A lock.** The repo's memory guard uses `flock`; a DST script waiting on a lock no one releases blocks
   forever. Check for `flock`/lockfile use on this path.
4. **`Process` / `SharedMem`** waiting on a child or a segment that never arrives under the runner.

## Constraints

- **Heavy runs one at a time.** `make dst` and anything on real segments: the memory guard's `flock` is the
  rule. Do not start a second heavy run beside one already going.
- **Never run `git stash`** — other sessions have uncommitted work in this tree and a stash takes it.
- Never edit `src/`, `packages/`, `tools/` outside what the fix genuinely needs; say so if it needs more.
- **No session content, credentials or host addresses** in a brief, a record, a fixture or a commit. This
  repo is **public**.
- You may push to `arniwesth/031-abi-8-0` and dispatch CI. Use `gh api` rather than the `gh pr`/`gh issue`
  porcelain: the available token lacks `read:org`, which those subcommands demand for unrelated metadata.
- A CI-only defect can only be proven fixed **in CI**. Iterate there; a green local run proves nothing here,
  since local is already green.

## Done means

1. The hanging script is **named**, with the CI evidence that names it.
2. The cause is **identified** — what it blocks on, not just which script.
3. A fix, or an explicit gate with a stated reason if the right fix is out of scope.
4. **`DST gates (rest)` completes in CI** — green, or red for a reason that is not this hang.
5. A `mutgate`-style check where one is meaningful: make the fixed path fail on a deliberate defect and
   pass again on restore. If the fix is a timeout or a redirect and a mutation gate is not meaningful, say
   so and say why rather than inventing a vacuous one.
6. Fold the per-target steps back into one `make --keep-going` line **only if** the hang is genuinely fixed
   (the comment at `.github/workflows/verify-extensions.yml:103` says the same).

Report back a typed envelope: the script, the cause, the fix, the CI run id that proves it, and anything
you had to touch beyond the above.

## One correction to carry, so you do not chase it

An earlier version of that workflow comment claimed *"main's scheduled run finishes the whole job in
2.4 min"*, implying a green CI baseline for these targets. **It is false and I have corrected it.** `main`
is the release mirror, months behind `main_dst`; its workflow has **one** job with no DST gates and no
`compaction_dst` step at all (run `35990826715`). **There is no known green run of these targets in CI to
diff against.** Do not go looking for one.
