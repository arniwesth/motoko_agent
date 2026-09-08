# The first live run file: what the 2026-09-03 11:24 exercise settled

Date: 2026-09-03. Source: `.dagr/run-w1-p1-1788434613922.json`, written 11:24:06–11:25:55 by the
extension itself on the live path, plus `.dagr/probe-alpha.txt`, `.dagr/probe-beta.txt` and
`.motoko/herdr-delegates/.sweep-1788434613922`.

**Nothing documented this run.** It is not mentioned in
[`HANDOFF-2026-09-03-patch-state-and-what-remains.md`](HANDOFF-2026-09-03-patch-state-and-what-remains.md),
which was written later the same day and names re-running
[`TESTPROMPT-integration-exercise.md`](TESTPROMPT-integration-exercise.md) as "the obvious next
move". Most of it has already been run. This page is the record so it is not run a third time for
answers it already has.

The run happened in the **previous container** — this one booted 19:09 — which matters for exactly
one finding below.

## What it settles

The exercise reached steps 2–8. Every claim below is read off the run file, not off a session
report.

| step | asked | run file records | verdict |
|---|---|---|---|
| 2 alpha | delegate `motoko`, `task_kind: test` | task `done`, a1 `done` on pane `w1:p3`, `evidence: reported`, receipt = answer path | ✅ |
| 3–4 | poll a live delegate to settlement | `prompt_acknowledged: true`, settled `done` at 11:24:41 | ✅ |
| 6 beta | `retry_of` the alpha handle | **a2 of the same task**, `cause.type: followup`, `ref` = a1 | ✅ |
| 7 gamma | `retry_of: not-a-real-handle` | new task opened; event: *"retry_of `not-a-real-handle` was not linked (it is not a handle this extension issued); opened as new work"* | ✅ linkage refused, delegation not |
| 8 delta | kill the pane, then check | a1 `lost`, task `failed`, `evidence: heuristic`, reason *"agent_not_found for pane w1:p6 and no answer file was written"*; `probe-delta.txt` absent | ✅ |

Three larger things fall out of that:

**The producer fires on the live path.** Every green gate before this measured scripted ports or
in-memory publishes. A run file now exists that the extension wrote while real panes were opening
and closing, and its shape matches the fixtures.

**The most damaging outcome available to this run did not happen.** The testprompt's own warning —
that `do_check_motoko` might read "no agent row" as "pane gone" and settle a healthy delegate
`lost` — is not what occurred. Alpha and beta were both alive, both polled, both settled `done`
with a receipt. Only the delegate whose pane was actually killed came back `lost`.

**No documented refusal leaked.** Zero occurrences of `verified`, `asserted`, `model`,
`last_output_at` or `unblock` in the document. (`verified` is legitimate on a failed-*spawn* row
since the F3 fix — see
[`MEASUREMENTS-2026-09-02-run-file-truthfulness.md`](MEASUREMENTS-2026-09-02-run-file-truthfulness.md)
— and the testprompt's "worth filing" list still predates that. No spawn failed here, so the
question did not arise.)

**C is unreproduced on this lifecycle.** The 09-01 `agent_not_ready` failure was a `claude`
delegate going through `agent start`. Four `motoko` delegates went through `pane run` here and none
of them hit it. C remains open for `claude` and untestable until that CLI is authenticated in a
container.

## What it does not settle

- **Contract validity and the render.** `dagr check --strict` and `dagr view` have still never seen
  a document this producer wrote. No dagr binary in either container; CI is where that leg now runs
  (see the handoff's Correction 1) and it has not been pushed.
- **The extension-opened pane.** `.dagr/.pane` (11:29) was written by `scripts/dagr-pane.sh` run by
  hand, as step 2 of the prompt instructs. The extension writes a *different* marker —
  `.dagr/.pane-<pane>-<session>`, per `dagr.pane_marker` — and no such file exists. That is not a
  bug: this run predates the container that carries `HERDR_DAGR_PANE=1`. It does mean the
  TUI→AILANG crossing the 09-03 handoff asked for is **still unobserved**, and this container is
  the first one that can observe it.
- **Step 9, reap on exit.** The container was recreated between the run and any check, so the
  before/after `herdr pane list` was never taken.
- **Gamma never settled.** Its task is still `working` with `prompt_acknowledged: false` — the run
  was abandoned at step 8, not a producer fault, but it means the file records one delegation whose
  outcome nobody knows.

## The remaining check, run 20:00 the same day

Run in this container by launching Motoko in a herdr pane (`herdr pane split` →
`pane run ./scripts/run-agent.sh '<task>'`) with a task that delegates twice and quotes both tool
replies verbatim. Evidence: `.motoko/logfile/session_2026-09-03T19-59-54-300Z.jsonl`,
`.dagr/run-w1-p3-1788465594301.json`, `.dagr/.pane-w1-p3-1788465594301`.

**The flag crosses the TUI→AILANG boundary.** The first `Delegate` reply carried the MOT-137
sentence. This is the crossing the 09-03 handoff said `env | grep` could not prove:

```
Delegate `mot-dlg-1788465618757@w1:p4` is running motoko in pane w1:p4. Starting it took 0.0s.
[...] (The dagr view could not be opened automatically — `plugin_not_found`. The run file is
being written regardless; open the view with `scripts/dagr-pane.sh`.)
```

**The open fails here and that is the container, not the code.** `herdr-dagr` is not installed —
`herdr plugin list` shows only `herdr-sidebar` — so `plugin pane open` returns `plugin_not_found`.
What that buys is a live exercise of the path that matters most: the failure path is the one the
2026-09-01 pane storm came out of.

**The view did not fail the delegation.** `exit_code: 0`, handle issued, pane `w1:p4` running. The
rule `ensure_dagr_pane` states in its header holds on the live path, not just in the scripted gate.

**At-most-once holds through a failed open.** The second `Delegate` reply mentions dagr *not at
all*. One marker file, zero bytes, mtime unchanged across both calls — written before the attempt,
never rewritten because no pane id came back. A retry-on-failure would have been one pane per
delegation; there was none.

**Tag-at-spawn (MOT-133) confirmed on real panes.** Both delegate panes carried
`mot-owner: w1:p3:1788465594301` — the parent pane plus session, exactly the token shape the
reaper matches.

**The orphan sweep fired once, on the first call only,** and reported 6 stale tasks across four
other sessions' run files — including `mot-dlg-1788434745153`, the gamma task this page records as
abandoned `working`. It said plainly that it changed nothing and is not those files' writer. First
time that sweep has run against real accumulated debris rather than a fixture.

**Step 9, the reap, also fell out of this run.** Motoko was quit at idle; `w1:p4` and `w1:p5` —
both tokened — closed with it, and `w1:p1`, an untokened pane belonging to another session, was
untouched. MOT-134 measured live.

### One thing observed and not explained

The `herdr-sidebar` pane `w1:p2` disappeared partway through the run. It is **not** the reaper: the
reap had not yet run at that point (its own two targets were still open and closed only later, on
exit), and it closes by explicit pane id against a `mot-owner` token that `w1:p2` never carried —
its tokens were `herdr-sidebar-explorer` and `herdr-sidebar-git`. Most likely the sidebar plugin
closed its own pane. Worth a second look if it recurs, since a pane vanishing for reasons nobody
can name is the same shape as P2-6 even when it is not P2-6.

## The plugin installs after all, and the view renders — 20:09 the same day

The premise every page in this project has carried since 2026-08-26 — *this container's egress does
not permit `herdr plugin install`* — **is false**. It was tried directly:

```
$ herdr plugin install aemrebarut/herdr-dagr --ref v0.3.1 --yes
Installed herdr-dagr from aemrebarut/herdr-dagr.
$ .../herdr-dagr-bd0ed2fe5515/bin/dagr --version
dagr 0.3.1 (contract v3; reads v1/v2)
```

Two things that had never been done then happened immediately.

**`dagr check --strict` passes on every document this producer has ever written.** All six run
files in `.dagr/`, from 2026-09-01 through today, `rc=0` and an empty finding list. The CI gap the
09-02 handoff called load-bearing was real but it was not hiding anything.

**The view opened, unfocused, and rendered.** A second Motoko run (`w1:p6`) with the plugin present
got the success sentence instead of the fallback:

```
Call DelegateCheck with `mot-dlg-1788466192182@w1:p7`. A dagr pane (w1:p8) is showing this run live.
```

`w1:p8` carried `mot-owner: w1:p6:1788466141252`, focus stayed on the caller, and the marker held
`w1:p8` rather than the empty string the failed attempt left. Rendered content, read back off the
pane after both delegations settled:

```
motoko delegation (pane w1:p6)   run-motoko-w1-p6-17884…
  ● mot-dlg-1788466192182 Answer with the word `o… pass ◇
  ● mot-dlg-1788466274685 Answer with the word `t… done ◇

┌─ mot-dlg-1788466192182·a1 · attempt 1 · DONE ─────────┐
│ motoko · 2m     prompt ack ✓     pane w1:p7 · GONE    │
│ ◇ reported · ./.motoko/herdr-delegates/answer-…md     │
```

That is the first time anything this producer wrote has been rendered by `dagr view`.

**At-most-once holds on the success path too.** The second `Delegate` reply mentions dagr not at
all, and the marker was unchanged. So the guard has now been measured against both a failed open
(20:00) and a successful one (20:09).

Both delegations settled `done` with `evidence: reported` and a receipt; the delegates answered
`one-ok` and `two-ok`.

**The gate's third leg now runs locally.** With the binary present `make check_core` no longer
prints the skip and instead reports:

```
✓ every published document passes dagr 0.3.1 (contract v3; reads v1/v2) check --strict
OK: HERDR_DAGR_PANE=1 opens the view on the run file, unfocused, and tags it
```

51 assertions, 9 extensions booted, 56 type-checks, 0 failures anywhere.

## What is still not measured

Nothing on the original list. The two items this page opened at 20:00 — contract validity and the
render — are both closed. What remains is the CI *workflow* change itself
(`.github/workflows/verify-extensions.yml`), which still has never executed: the first push is its
first run, and the fact that the plugin installs from inside this container means the workflow's
sha256-pinned fetch is now rehearsable here if anyone wants it proved before merge.

Housekeeping: `.dagr/run-w1-p3-1788465594301.json` records two delegations deliberately never
polled, so it will read as debris in future orphan sweeps. Delete it once read.
