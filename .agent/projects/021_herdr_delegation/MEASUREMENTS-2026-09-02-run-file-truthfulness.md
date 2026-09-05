# Run-file truthfulness: what the 2026-09-01 live exercise found, and what is fixed

Date: 2026-09-02. Source: the live integration exercise driven by
[`TESTPROMPT-integration-exercise.md`](TESTPROMPT-integration-exercise.md), logged at
`.motoko/logfile/session_2026-09-01T19-12-41-501Z.{md,jsonl}`. That session's own report (19:50)
is the F1–F5 vocabulary used below; everything here was re-checked against the source before
being acted on.

## Fixed in this change

**F3 — the run file omitted work the session actually spent.** `do_delegate` had nine
`err_result` exits and not one of them touched dagr. Two `claude` delegations each consumed a
pane, an `agent start` and a task file, failed at `agent prompt` with `agent_not_ready`, and left
the document with no row at all: a reader saw a session that delegated three times, when it had
delegated five.

The fix is not to open the task earlier. `dagr.open_task`'s comment refuses that for a good
reason — a task appended at `pane split` survives as a phantom `working` row for a delegation that
never happened — and that reason still holds. Instead `dagr.open_failed_task` opens and settles in
**one transition**: the task is born `failed` with an already-terminal attempt, so it is never
observable as `working`, and the spend is on the record.

It is called from the five paths where something was actually spent, all of them after
`pane split` returned a pane id: the motoko payload-quoting refusal, `pane run` failing,
`agent start` failing, the readiness gate refusing, and `agent prompt` failing. The refusals
*above* the split — an unpermitted kind, the depth gate, an unsafe path — still write nothing,
because they spend nothing and issue no handle.

`verified` is the evidence tier for exactly this one row, and the module header now says so.
Every other settle grades a claim about a *delegate's answer*, which nothing independently
checks, so those all land at `reported`. This one grades a claim about the *spawn*, and its
evidence is herdr's own exit status read by this code — with that exit code as the receipt:

```json
"outcome": {"result": "failed", "evidence": "verified",
            "receipt": "herdr exit 1, code `agent_not_ready`",
            "reason": "the `claude` agent started and passed the readiness gate, but
                       `herdr agent prompt` refused the task; the pane was closed again"}
```

`started_at` and `ended_at` are two clock readings, not one: collapsing them would state that a
spawn which spent 3.9s on `agent start` took no time at all.

**A refused `retry_of` reached the graph and not the caller.** Steps 6 and 7 of the exercise both
returned an ordinary success; the refusal existed only as a `note` event in the run file, so the
model went on believing it had chained a retry. `dagr_record`'s transition callback now returns a
`DagrStep { doc, note }` instead of a bare `Json`, and `dagr_open` puts the refusal in both
places — the event, because the graph must show why the rework count did not move, and the tool
result, because the delegation the model just made is not the retry it asked for. Still not an
error: §3.6 refuses the linkage, never the work.

**F1 — nobody was looking at the records.** `.dagr/` held `run-w1-p6-1788279509710.json` from a
session three hours earlier, carrying task `mot-dlg-1788282630477` `working` on pane `w1:p8`, a
pane that no longer existed. The startup sweep reported nothing and was right to: it enumerates
*panes*, and that pane was gone.

The sweep now has a second half. `dagr.abandoned_tasks` reads the other run files in `.dagr/` and
reports any task whose **latest** attempt is non-terminal on a pane **not in the live pane list**.
Both conditions matter: an in-flight attempt whose pane is still there may belong to a session
that is still running, and calling it abandoned would be the same class of misreport pointed the
other way.

It **reads and never writes**. One writer per file is what keeps two Motokos in one checkout from
clobbering each other (§5) and it gets no exception for a file whose writer merely looks dead —
"looks dead" is the judgement P2-6 measured going wrong, one class over. The output is a sentence
that says so; the correction stays with whoever owns that file.

Verified against the real artifact: fed the actual `run-w1-p6-1788279509710.json` and this
container's live `herdr pane list`, the detector returns
`mot-dlg-1788282630477 (review) on pane w1:p8` and nothing for the measurement session's own run
file, whose tasks all settled.

## Gates

`make check_core` goes from 19 assertions to 28, all passing. Eight are new:

| assertion | what it pins |
|---|---|
| a spawn that fails after the split is recorded as a failed task | F3, on the `agent_not_ready` shape |
| the model still gets the full failure explanation | the error text survived the rewrite |
| that failed task is never observable as working | §3.2's phantom row still cannot appear |
| the failed spawn carries a mechanical receipt, not a claim | the tier is earned, not asserted |
| a refused retry_of link is stated in the tool result, not only the run file | the caller is told |
| an in-flight task in ANOTHER session's run file is reported when its pane is gone | F1, with this session's own in-flight task asserted **absent** from the report |
| the first delegation of a run says how to open the dagr view | D, discoverability from inside a session |
| later delegations do not repeat the view pointer | once per run, on the output the model reads most |

The MOT-136 scripted ports grew a `fail_at` discriminator (`""` / `"split"` / `"start"` /
`"prompt"`) in place of the old `split_ok` boolean, which could only fail the split and therefore
could not reach F3 at all. The MOT-133 `Case` type grew `expect_not_in_out`, because a stale-record
report that names the wrong file is worse than no report and only a must-not-appear assertion
catches it.

**The contract leg ran for the first time.** `verify_dagr_producer`'s second half was skipping
here for want of a binary; `herdr plugin install aemrebarut/herdr-dagr --ref v0.3.1 --yes` fixes
that, and every published document — including the new born-failed shape — passes
`dagr 0.3.1 check --strict`. CI still skips this leg: no workflow installs the plugin.

## D — the view can now find the run (same change)

`dagr.run_file` writes `.dagr/run-<pane>-<session_ms>.json`; `dagr view` resolves `$DAGR_RUN`,
then `.dagr/run.json`, then `./run.json`. Those never intersect, so the stock
`herdr plugin action invoke open-dagr` renders whatever else is in the directory — in this
checkout, the hand-authored 2026-08-26 install probe. That is what cost the 2026-09-01 session
twenty minutes and about ninety scratch panes, with its own run file unread on disk throughout.

The producer was **not** changed to write `.dagr/run.json`. A shared name, symlink or otherwise,
reintroduces exactly the multi-writer shape §5 refuses: two Motokos in one checkout would fight
over where it points, and a reader who opened the pane would silently get the other session's
graph. Instead the run file is resolved explicitly and passed down as `$DAGR_RUN`:

```sh
make dagr                       # newest run file
make dagr ARGS='--pane w1:p1'   # a specific producer's run
make dagr ARGS=--print          # print the herdr command, open nothing
```

`scripts/dagr-pane.sh` resolves the file (explicit `--file`, or by `--pane`, or newest), **lists
every candidate and says which it chose** when there is more than one — a silent newest-wins would
show the wrong graph and look right doing it — refuses with the pinned install command if the
plugin is missing, and names `.dagr/run.json` if it exists, because that is what the stock action
will render instead. It does not delete it: removing another tool's file is not this script's call.

**One pane, not a pile.** `$DAGR_RUN` is fixed at spawn, so re-pointing the view means replacing
the pane. The first draft called `plugin pane close dagr`, which turns out **not** to find a pane
opened with `plugin pane open` — verified here: `plugin_pane_not_found` against a live,
`dagr`-labelled pane. Closing by *label* is the rule the F-5 sweep refuses for measured reason, so
the script records the pane id it opened in `.dagr/.pane` and closes only that, and only while
`pane get` still reports it as a dagr pane (ids are reused). Verified: three consecutive runs
leave exactly one pane.

From inside a session, `dagr_open` now adds a **once-per-run** line to the first delegation's
result — addressed to the operator, not phrased as something to go and do, because the same
session's other failure was opening view panes in a loop. Gated both ways: it must appear on the
first delegation and must not repeat on later ones.

**Rendering checked, not assumed.** The new born-failed row had never been drawn by anything. It
renders `✗ mot-dlg-9000 … fail ◆`, and the attempt drawer reads
`◆ verified · herdr exit 1, code \`agent_not_ready\` · the \`claude\` agent started and passed the
readiness gate, but \`herdr agent prompt\` refused the task; the pane was closed again` — the
filled diamond being the `verified` tier, which is the honest reading for a failure this code
watched happen.

## Not fixed here, and why

**F2 — `motoko` delegation is still refused in this container.** `env | grep HERDR_ALLOWED_KINDS`
prints nothing; [`PATCH-agent-confined-allowed-kinds.md`](PATCH-agent-confined-allowed-kinds.md)
is written but unapplied, and `.devcontainer` is mounted read-only in here by design. Until an
operator applies it from the host, the `motoko` lifecycle and its tag-at-spawn write point cannot
be exercised at all.

**F5 — `ended_at` on a settle is the moment of the check, not of the work.** The contract is
explicit that these differ and that the gap is real information. Closing it needs the answer
file's mtime, and `ExtPathStat` carries only `kind`; widening the ABI is a 16-package change (017)
and `stat`/`date -r` disagree between GNU and BSD. Left as it stands rather than papered over.

**C — `agent_not_ready` on an agent herdr itself started.** Reproducible 2/2 in the exercise:
`agent start` succeeded, the readiness gate passed, and `agent prompt` then refused with *"the
pane holds an agent herdr did not start"*. This change makes that failure **visible** in the run
file; it does not explain it. Needs live reproduction to tell a start/prompt race from a herdr bug.

**A — the runtime did not stop.** Not a herdr finding, and the largest one in the log. The final
turn ran 197 steps of an identical open-pane → read → close cycle, re-emitting the same answer
every ~15s for twenty minutes, with no `run_summary` and no `done`. `empty_stop_guard` and
`progress_contract_guard` were both loaded; both only ever push the model to *continue*, and
nothing anywhere detects repetition. `agent.max_steps: 300` was the only ceiling and it was never
reached. NOTE-006 §2 predicts this shape from compaction eliding older tool outputs.
