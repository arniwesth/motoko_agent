# Handoff: run-file truthfulness, the dagr view, and the loop guard

Date: 2026-09-02
Branch: `arniwesth/mot-133-f-5-extension-side-tag-delegates-at-spawn-report-stale`, last commit
`47db38a`. **Everything below is UNCOMMITTED in the working tree.**

Status: **three of the five findings from the 2026-09-01 live exercise are fixed and gated
(F3, F1, the refused-`retry_of` silence, plus the dagr view and the runaway loop). Two are open
and one of those is blocked on an operator step only you can take.**

Source for everything here: `.motoko/logfile/session_2026-09-01T19-12-41-501Z.{md,jsonl}` — the
live run of [`TESTPROMPT-integration-exercise.md`](TESTPROMPT-integration-exercise.md). Its own
report (19:50 in the `.md`) is the F1–F5 vocabulary; every claim was re-checked against source
before being acted on.

Full write-ups, and they carry the reasoning this page only indexes:
1. [`MEASUREMENTS-2026-09-02-run-file-truthfulness.md`](MEASUREMENTS-2026-09-02-run-file-truthfulness.md)
   — F3, F1, the retry-link silence, and the dagr view (tracks B, E, D).
2. [`../028_verified_runtime_closing_the_loop/NOTE-007-the-loop-that-would-not-stop.md`](../028_verified_runtime_closing_the_loop/NOTE-007-the-loop-that-would-not-stop.md)
   — the runaway loop and the guard (track A).

## Where the gate stands

`make check_core`: **46 assertions, 0 failures**, 9 extensions booting, 56 core modules
type-checking, `registry_gen_check` clean. It was 19 assertions at the start of the day.

**The contract leg ran for the first time.** `verify_dagr_producer`'s second half had been
skipping for want of a binary. Install it pinned and it runs:

```sh
herdr plugin install aemrebarut/herdr-dagr --ref v0.3.1 --yes
```

Every published document — including the new born-failed task shape — passes
`dagr 0.3.1 check --strict`. **CI still skips this leg**: no workflow installs the plugin. That is
the one gap in the gate story and it is worth closing before this branch merges.

## What changed

### F3 — the run file omitted work the session actually spent

`do_delegate` had nine `err_result` exits and none touched dagr, so two `claude` delegations that
each burned a pane, an `agent start` and a task file left **no row at all**. The fix is not to open
the task earlier — `open_task`'s comment refuses that, and the reason still holds. `open_failed_task`
opens and settles in **one transition**: born `failed` with an already-terminal attempt, never
observable as `working`. Wired into the five paths where something was spent, all after
`pane split` returned a pane id. `verified` is the tier for exactly that row and the module header
now says why: it grades a spawn this code watched fail, with herdr's exit code as the receipt.

### The refused `retry_of` reached the graph and not the caller

`dagr_record`'s transition callback now returns `DagrStep { doc, note }` instead of bare `Json`, so
`dagr_open` states the refusal in the tool result as well as the run file.

### F1 — nobody was reading the records

The sweep enumerates *panes*, so a previous session's frozen `working` task on a dead pane was
invisible. It now has a second half that reads the other run files in `.dagr/` and reports any task
whose latest attempt is non-terminal on a pane absent from the live list. **Reads and never
writes** — one writer per file gets no exception for a file whose writer merely looks dead.

### D — the view can find the run

`scripts/dagr-pane.sh` + `make dagr`. The producer was **not** changed to write `.dagr/run.json`;
that is the multi-writer shape §5 refuses. The run file is resolved and passed as `$DAGR_RUN`.
`dagr_open` also adds a once-per-run pointer to the first delegation's result, addressed to the
operator rather than phrased as something to go and do.

### A — the runaway loop

New package `packages/motoko-ext-repetition-guard/`, enabled in the `default` profile after the two
guards it argues against. `ToolPolicy` denies; `SolverJudge` accepts. See NOTE-007 — including the
first design, which was reasonable and which replaying the real transcript refuted.

## The working tree, exactly

Twelve modified, five new — plus files that predate this session and are **not** mine.

| mine, modified | why |
|---|---|
| `packages/motoko-ext-herdr/dagr.ail` | `open_failed_task`, the F1 scan, `run_file_name` |
| `packages/motoko-ext-herdr/herdr.ail` | `DagrStep`, `dagr_failed`, `scan_abandoned`, the five failure paths, the view pointer |
| `scripts/verify_mot136_dagr_producer.ail` | `fail_at` discriminator; 6 new assertions |
| `scripts/verify_mot133_owner_tag.ail` | `expect_not_in_out`; the F1 case |
| `Makefile` | `verify_repetition_guard` into `check_core`; `make dagr`; a stale comment |
| `ailang.toml`, `ailang.lock`, `src/core/ext/registry_generated.ail` | registering the new package |
| `.motoko/config/default/config.json` | `repetition_guard` in the order — see the warning below |

| mine, new |
|---|
| `packages/motoko-ext-repetition-guard/` (3 files) |
| `scripts/verify_repetition_guard.ail` |
| `scripts/dagr-pane.sh` |
| `MEASUREMENTS-2026-09-02-run-file-truthfulness.md`, `NOTE-007-…md` |

**Not mine, already in the tree when I started** — decide separately whether they belong in this
commit: `.devcontainer/agent_confined/docker-compose.yml` (the reap-on-exit patch),
`.agent/projects/028_…/README.md`, `papers/README.md`, and the untracked `NOTE-005`, `NOTE-006`,
`PATCH-agent-confined-allowed-kinds.md`, `agent-confined-allowed-kinds.patch`,
`TESTPROMPT-integration-exercise.md`, `029_cslib_proof_tier/`, `.motoko/artifacts/`,
`little-coder/`.

**One thing to look at before committing `config.json`.** Its diff carries two changes that are not
mine and that I did not make: the default model moved `glm-5.3-flash` → `gemini-3.8-flash`, and
`agentcli` was dropped from the extension order (leaving trailing whitespace on the
`compaction_structural` line). Those were in the tree when I arrived. My change is the single
`repetition_guard` line. Split the commit or keep them together deliberately — but do not ship them
by accident.

## What is still open

**F2 / the operator step, and it blocks the rest.** `env | grep HERDR_ALLOWED_KINDS` prints
nothing here. `.devcontainer` is mounted `virtiofs ro` from
`/Users/arniwesthhansen/Projects2/private/motoko_agent/.devcontainer`, and `agent.sh` refuses to run
inside a container by design. On the **Mac**:

```sh
cd /Users/arniwesthhansen/Projects2/private/motoko_agent
git apply .agent/projects/021_herdr_delegation/agent-confined-allowed-kinds.patch
git diff --stat .devcontainer/agent_confined/docker-compose.yml   # expect 46 insertions, not 27
.devcontainer/agent_confined/agent.sh                             # recreate; ENDS every session in the container
```

`git apply --check` passed on 2026-09-02, so it applies cleanly against this tree. Details and the
verification steps are in
[`PATCH-agent-confined-allowed-kinds.md`](PATCH-agent-confined-allowed-kinds.md); the one that
matters is that `env` showing the variable is necessary but not sufficient — the real check is a
`Delegate` with `kind: "motoko"` returning a handle.

**C — `agent_not_ready` on an agent herdr itself started.** Reproducible 2/2 in the exercise:
`agent start` succeeded, the readiness gate passed, `agent prompt` then refused with *"the pane
holds an agent herdr did not start"*. This change makes that failure **visible in the run file**;
it does not explain it. Needs a live reproduction to tell a start/prompt race from a herdr bug, and
that needs F2 applied or an authenticated `claude` CLI.

**F5 — `ended_at` is the moment of the check, not of the work.** The contract is explicit that
these differ and that the gap is information. Closing it needs the answer file's mtime;
`ExtPathStat` carries only `kind`, widening the ABI is a 16-package change (017), and `stat` /
`date -r` disagree between GNU and BSD. Left as it stands rather than papered over.

**The max-tokens truncation.** The turn immediately before the runaway finished with
`output_tokens: 4096` and `output: ""` — a truncation surfaced to the operator as an empty answer
(`empty_stop_finalize` at step 0, then `done` with no output). Separate bug, untouched.

**No upstream filings.** Decided 2026-09-02. Two would have been candidates —
`aemrebarut/herdr-dagr` for a newest-`run-*.json` fallback in `dagr view`, and herdr itself for
`plugin pane close <id>` returning `plugin_pane_not_found` against a live plugin-opened pane. Both
are worked around locally in `scripts/dagr-pane.sh`; neither is blocked.

## The obvious next move

Re-run [`TESTPROMPT-integration-exercise.md`](TESTPROMPT-integration-exercise.md) once F2 is
applied. It now has what it lacked: a dagr pane that shows the live run (`make dagr`), a guard that
stops it looping for twenty minutes, and a producer that records failed spawns instead of
swallowing them. That run is what settles C, and it is the first time the exercise will measure the
`motoko` lifecycle at all.

## Facts worth not rediscovering

- `SolverJudge` fires **only** on a step with no tool calls (`session.ail`, `hybrid_attempt = None`
  arm). Any guard that must see a tool-calling loop has to be a `ToolPolicy`.
- `history_slice` at `ToolPolicy` time is `st.msgs ++ [assistant]` (`pending_tool_context`) — the
  full history, with the message carrying the current call last. Results pair back by
  `tool_call_id`; calls still in flight have none.
- **No extension seam can halt a tool-calling loop.** `ToolPolicyDecision` has no terminal variant.
  `Pending` would suspend for an operator decision and is deliberately unused — `approval_read`
  blocks, and a hung session is worse than a looping one. `agent.max_steps` is still the only hard
  ceiling.
- `dagr view` resolves `$DAGR_RUN` → `.dagr/run.json` → `./run.json`. The producer's
  `run-<pane>-<session_ms>.json` matches none of them, and that is deliberate (§5).
- `herdr plugin pane close <name>` does **not** find a pane opened with `herdr plugin pane open` —
  `plugin_pane_not_found` against a live, `dagr`-labelled pane. `dagr-pane.sh` tracks the id it
  opened in `.dagr/.pane` and closes only that.
- `.dagr/run.json` in this checkout is the hand-authored 2026-08-26 install probe. It is what the
  stock `open-dagr` action renders. Nothing deletes it; `dagr-pane.sh` names it.
