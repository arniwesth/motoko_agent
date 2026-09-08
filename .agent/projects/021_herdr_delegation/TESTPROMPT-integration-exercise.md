# Test prompt: exercise the delegation → dagr integration end to end

Date: 2026-09-01. Purpose: drive MOT-133 (tag at spawn + sweep), MOT-136 (the producer) and
MOT-134 (reap on exit) through a **live** Motoko session, because every gate that currently passes
is scripted-ports or in-memory. No document this code produced has ever been rendered by
`dagr view`, and `.dagr/` still holds only the hand-authored `run.json` from the 2026-08-26 install
probe.

This is a *measurement*, not a fix session. The prompt below tells Motoko to report what it
observes and change nothing.

---

## Operator pre-flight (before launching Motoko)

Run these in the pane you will launch Motoko from. Each one closes a known hole.

```sh
# 1. Both lifecycles reachable. The default allowed set is "claude" ALONE
#    (types.default_allowed_kinds), and NOTE-005 (2026-09-01) recorded a claude
#    delegate failing to spawn — herdr matched no screen rule, so the pane was
#    closed. `motoko` uses `pane run` and never `agent start`, so it does not
#    depend on screen-rule matching and is the path that still works when the
#    coding-agent CLIs are unauthenticated.
export HERDR_ALLOWED_KINDS=claude,motoko

# 2. The contract check needs a PINNED binary; unpinned install needs Cargo.
herdr plugin install aemrebarut/herdr-dagr --ref v0.3.1 --yes
command -v dagr || export PATH="$PATH:$(echo ~/.config/herdr/plugins/github/herdr-dagr-*/bin)"
command -v dagr || ls ~/.config/herdr/plugins/github/herdr-dagr-*/bin/dagr

# 3. Is the claude CLI actually authenticated? If this drops to a sign-in
#    screen, step 2 of the prompt is EXPECTED to fail and that failure is a
#    result, not a blocked run.
claude --version
```

Leave `HERDR_REAP_ON_EXIT=1` as the container sets it — step 9 depends on it.

## What each step is for

| step | write point exercised | design ref |
|---|---|---|
| 1 | first-call orphan sweep, once per run | F-5 D3, MOT-133 |
| 2 | `Delegate` success → task opened, attempt a1 `doing`, `kind` from `task_kind` | §3.2 |
| 2 | `pane report-metadata` tag at spawn | F-5 D1, MOT-133 |
| 2 | open live dagr viewer pane via `scripts/dagr-pane.sh` | MOT-136 |
| 3 | `DelegateCheck` mid-flight → latches `prompt_acknowledged`, settles nothing | §3.4 |
| 4 | answer on disk → attempt `done`, evidence `reported`, receipt = answer path | §4.2 |
| 5 | second check on a settled delegate → idempotent, no second settlement | §3.5 |
| 6 | `retry_of` on a live handle → attempt a2 of the SAME task, cause `followup` | §3.6 |
| 7 | `retry_of` on a handle this extension never issued → refuses the LINKAGE only, notes why | §3.6 |
| 8 | pane killed under the delegate → `agent_not_found` → attempt `lost`, task `failed` | §4, failure codes |
| 9 | reap on clean exit closes this session's panes by token, never by name | F-5 D2, MOT-134 |

Steps 2–8 all publish, so each one is also a `mv`-transaction exercise.

**One thing this run is expected to settle, and might settle badly.** The motoko lifecycle asks
`agent get <pane>` whenever the answer file is not yet on disk, and treats `agent_not_found` as
proof the delegate died (`herdr.ail`, `do_check_motoko`). But MOT-133's own measurement recorded a
live motoko delegate that had *released its agent authority* and so carried no agent row at all.
If those are the same condition, step 3 or step 4 will settle a healthy delegate as `lost` and the
run file will record a failure that did not happen — which is precisely the class of misreport
this producer exists to prevent. Step 8 exists to prove the gate fires when the pane really is
gone; steps 3–4 exist to prove it does not fire when the pane is fine. Watch both.

---

## The prompt

Paste this as a single message to Motoko.

> You are exercising the herdr delegation integration so I can see whether the dagr run file it
> writes matches what actually happened. **Report, do not repair.** If a step fails, record the
> exact error and go on to the next step — a failure is a result. Do not edit any source file, do
> not hand-write anything under `.dagr/`, and do not run `make`.
>
> Work through these in order.
>
> 1. Before delegating anything, tell me whether your first tool call produced an orphan-sweep
>    report, and quote it verbatim if so. If there was none, say so — that is the expected result
>    on a clean server.
>
> 2. Delegate this task, with `task_kind: "test"` and `kind: "motoko"`:
>    *"Write the single line `alpha-ok` to `.dagr/probe-alpha.txt`, relative to the repo root.
>    Create nothing else. Then answer with the word `alpha-ok` and stop."*
>    Report the handle you got back and how long the call took.
>    Immediately after delegating, open the live dagr viewer pane by running `scripts/dagr-pane.sh`
>    from the shell so the graph is displayed live during the test. Report the pane opened.
>
> 3. Immediately call `DelegateCheck` on that handle once, before the delegate can plausibly be
>    done. Report the state verbatim.
>
> 4. Poll `DelegateCheck` until it settles or until you have called it eight times, whichever comes
>    first. Report the final state and the answer text.
>
> 5. Call `DelegateCheck` on that same handle one more time after it settled. Report whether the
>    result changed.
>
> 6. Delegate a second task with `retry_of` set to the handle from step 2, `task_kind: "test"`,
>    `kind: "motoko"`:
>    *"Write the single line `beta-ok` to `.dagr/probe-beta.txt`, relative to the repo root. Then
>    answer with the word `beta-ok` and stop."*
>    Poll it to settlement the same way.
>
> 7. Delegate a third task with `retry_of: "not-a-real-handle"`, `task_kind: "docs"`,
>    `kind: "motoko"`:
>    *"Answer with the word `gamma-ok` and stop. Write no files."*
>    Report whether the delegation succeeded and whether anything told you the retry link was
>    refused.
>
> 8. Delegate a fourth task, `task_kind: "impl"`, `kind: "motoko"`:
>    *"Write the single line `delta-ok` to `.dagr/probe-delta.txt`, relative to the repo root. Then
>    answer with the word `delta-ok` and stop."*
>    Then, **without polling it at all**, kill that delegate's pane from the shell straight away —
>    `herdr pane close <the pane_id in the delegation metadata>` — and only then call
>    `DelegateCheck` on the handle. Report exactly what you were told, and say whether
>    `.dagr/probe-delta.txt` exists afterwards.
>
> 9. Now find the run file the extension has been writing: `ls -t .dagr/run-*.json | head -1`.
>    Print it whole with `cat`. Do not open `.dagr/run.json` — that is an unrelated file from an
>    older session.
>
> 10. Produce a table with one row per step 2–8, three columns: what you asked for, what the tool
>     told you, and what the run file records for it. Name every place the three disagree. I am
>     specifically asking whether the run file claims anything the tool output does not support —
>     an attempt still in flight that finished, a settled task still carrying an `unblock` line, an
>     `evidence` tier above `reported`, or a task for a delegation that never started.
>
> 11. Finally, list the panes carrying an ownership token: `herdr pane list`, and for each pane in
>     it `herdr pane get <id>`. Report which ones carry a `mot-owner` token and what the value is.

---

## Operator post-run checks

Motoko cannot do these — 9 needs a binary the prompt must not assume, and 10 needs Motoko to be
gone.

```sh
# 1. CONTRACT VALIDITY. This is the leg CI currently skips (no workflow installs
#    dagr), so it has never run against a document the producer actually wrote.
RUN=$(ls -t .dagr/run-*.json | head -1)
dagr check "$RUN" --strict --json

# 2. THE RENDER. The whole point of the producer, never once observed.
dagr view "$RUN"

# 3. REAP ON EXIT (MOT-134). Leave one delegate running, quit Motoko cleanly,
#    then confirm its pane is gone and NOTHING ELSE is:
herdr pane list                 # before
#   ... quit Motoko ...
herdr pane list                 # after — only the tokened delegates should have gone

# 4. Clean up the probe files the delegates wrote.
rm -f .dagr/probe-*.txt
```

## What would count as a failure worth filing

- The run file does not exist at all after a successful delegation → the producer never fired on
  the live path, and every green gate is measuring the scripted ports only.
- `dagr check --strict` rejects it → the CI gap in the Makefile's second leg is load-bearing, and
  the fixtures the in-memory test publishes are not the shapes the live path publishes.
- `evidence: "verified"`, an `asserted` tier, a `model` field, or `last_output_at` appears → a
  documented refusal leaked (dagr design §3.1, §3.4, §4).
- A settled task still carries `unblock` → the W205 clear-on-settle path regressed.
- Step 8 reports anything other than `lost` → the `agent_not_found` gate is not classifying.
- Steps 3–4 report `lost` for a delegate that was alive and later delivered → the gate is
  firing on "no agent row" rather than on "pane gone", and the producer is publishing a
  failure that never happened. This is the most damaging outcome available to this run.
- Step 9's reap closes a pane with no `mot-owner` token, or one belonging to another session →
  stop and treat it as P2-6, the one rung that can destroy another session's work.
