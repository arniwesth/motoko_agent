# Handoff: where the three compose patches actually stand

Date: 2026-09-03
Branch: `arniwesth/mot-133-f-5-extension-side-tag-delegates-at-spawn-report-stale`, HEAD `47db38a`.
**Everything below HEAD is still UNCOMMITTED in the working tree.**

This session built nothing. It read the prior work, re-ran the gate, and checked each pending patch
against the tree and against the live container. The one thing it found worth writing down is that
**the picture in [`HANDOFF-2026-09-02-run-file-truth-view-and-loop-guard.md`](HANDOFF-2026-09-02-run-file-truth-view-and-loop-guard.md)
is out of date in two places, both in the good direction** — F2 is cleared and the CI gate gap is
closed. A session that starts from that page will go looking for work that is already done.

Read this page for patch state and the gate; read the 09-02 handoff for the reasoning behind every
extension-side change, which has not changed.

## The gate, re-run today

```
make check_core     51 OK, 0 FAIL
                    verify_extensions (default): 9 booted, 0 failed
                    src/core/ type-check: 56 passed, 0 failed
```

It was 46 assertions on 2026-09-02; the five new ones are MOT-137's
(`scripts/verify_mot137_dagr_pane.ail`, wired into `check_core` as `verify_herdr_dagr_pane`).

**The contract leg still skips locally** — no dagr binary in this container:

```
(skipping the contract leg: no dagr binary — herdr plugin install aemrebarut/herdr-dagr --ref v0.3.1 --yes)
```

That is the designed behaviour, not a failure: loud enough for a person, and `DAGR_REQUIRED=1`
turns it red where nobody reads the log. Which brings us to the first correction.

## Correction 1 — the CI gap the 09-02 handoff called "the one gap in the gate story" is closed

That page said *"CI still skips this leg: no workflow installs the plugin"* and asked for it to be
closed before merge. It has been. `.github/workflows/verify-extensions.yml` is modified in the
working tree with a step that fetches the pinned release asset the plugin's own `install.sh` would,
verifies its sha256, and sets `DAGR_REQUIRED: '1'` on the `check_core` step so a fetch that quietly
failed cannot put the skip back. The version is parsed out of `DAGR_VERSION` in the Makefile rather
than repeated, so the version CI checks against cannot drift from the version the instruction
installs.

**Unverified here, and worth knowing:** this container cannot reach GitHub releases to rehearse that
step, so the workflow change has been read but never executed. First push to CI is its first run.

## Correction 2 — F2 is cleared; two of the three patches are already live

The 09-02 handoff opens its "still open" section with F2 as the blocker for everything else. It is
no longer blocking. Measured in this container today:

```
$ env | grep ^HERDR
HERDR_ALLOWED_KINDS=claude,motoko
HERDR_REAP_ON_EXIT=1
...
```

and in the tree, `.devcontainer/agent_confined/docker-compose.yml` is +46 lines against HEAD with
`HERDR_REAP_ON_EXIT` at `:219` and `HERDR_ALLOWED_KINDS` at `:246`. Both patches applied on the Mac
and both delivered on a recreate. `git apply --check` now **fails** for both — which is what
"already applied" looks like, not a problem.

So the state of the three, today:

| patch | state |
|---|---|
| `agent-confined-reap-on-exit.patch` | **applied and live.** Its `PATCH-…md` is now history |
| `agent-confined-allowed-kinds.patch` | **applied and live.** Same |
| `agent-confined-dagr-pane.patch` | **outstanding.** `git apply --check` passes cleanly today |

The two spent patch files and their `PATCH-…md` companions are worth keeping until the branch
merges — they are the record of *why* a confined container permits self-delegation at all — and
worth deleting or folding into the commit message after. Don't leave them lying around looking
pending.

## The one patch left, and how to apply it

MOT-137's operator half. The extension side is landed and gated; this is the line that points
anything at the run file in this repo's own container.

`.devcontainer` is mounted `virtiofs (ro,relatime)` here — `touch .devcontainer/.write_probe` fails
with `Read-only file system`, which is the mount working — so it cannot be applied from inside. On
the **Mac**:

```sh
cd /Users/arniwesthhansen/Projects2/private/motoko_agent
git apply .agent/projects/021_herdr_delegation/agent-confined-dagr-pane.patch
git diff --stat .devcontainer/agent_confined/docker-compose.yml   # expect 70 insertions, not 46
.devcontainer/agent_confined/agent.sh                             # recreate — ENDS every session in the container
```

24 added lines, 23 of them the comment block; the effective line is `HERDR_DAGR_PANE: "1"` after
`HERDR_ALLOWED_KINDS`. Reasoning and the revert path are in
[`PATCH-agent-confined-dagr-pane.md`](PATCH-agent-confined-dagr-pane.md).

**The recreate is not optional and `export` is not a substitute.** The variable is read when the
**TUI process** starts, not per tool call, and `docker compose` only delivers an env change on
recreate. Exporting it in a shell where Motoko is already running changes nothing — that is exactly
how the first integration exercise came to be refused five times in a row on `HERDR_ALLOWED_KINDS`.

`env | grep HERDR_DAGR_PANE` is necessary and not sufficient; the variable has to cross the
TUI→AILANG boundary. The real check is a `Delegate` that opens an unfocused view pane on the first
call and **does not open a second one** on the next.

Nothing breaks without it. The run file is written on the same schedule to the same path either
way; the flag only decides whether anything is pointed at it, and `make dagr` still opens the view
by hand.

## What is still genuinely open

Unchanged from 09-02 except that C is now reachable:

- **C — `agent_not_ready` on an agent herdr itself started.** Reproducible 2/2 in the 09-01
  exercise: `agent start` succeeded, the readiness gate passed, `agent prompt` refused with *"the
  pane holds an agent herdr did not start"*. This work makes the failure **visible** in the run
  file; it does not explain it. It needed F2 or an authenticated `claude` CLI — F2 is now applied,
  so **re-running [`TESTPROMPT-integration-exercise.md`](TESTPROMPT-integration-exercise.md) is
  the obvious next move**, and it will be the first run to measure the `motoko` delegate lifecycle
  at all. Apply the dagr-pane patch first so the run is watchable while it happens.
- **F5 — `ended_at` is the moment of the check, not of the work.** Needs the answer file's mtime;
  `ExtPathStat` carries only `kind`, widening the ABI is a 16-package change (project 017), and
  `stat` / `date -r` disagree between GNU and BSD. Left standing rather than papered over.
- **The max-tokens truncation.** The turn before the 09-01 runaway ended `output_tokens: 4096`,
  `output: ""` — a truncation surfaced to the operator as an empty answer. Separate bug, untouched.
- **No upstream filings**, decided 2026-09-02 and not revisited. Both candidates are worked around
  in `scripts/dagr-pane.sh`; neither blocks anything.

## Before committing, two things that are not this work

Both flagged on 09-02, both still true, both still in the diff:

1. **`.motoko/config/default/config.json`** carries changes nobody in these sessions made: the
   default model moved `glm-5.3-flash` → `gemini-3.8-flash`, and `agentcli` was dropped from the
   extension order, leaving trailing whitespace on the `compaction_structural` line. The only line
   from this work is `repetition_guard`. Split the commit or keep them deliberately — but do not
   ship them by accident.
2. **Untracked and not from this thread:** `.agent/projects/029_cslib_proof_tier/`,
   `.motoko/artifacts/`, `little-coder/`, `NOTE-008-…`, and the modified `papers/README.md` and
   `028_…/README.md`. Decide separately whether they belong in this commit.

Also new since the 09-02 handoff and not mentioned there:
[`NOTE-2026-09-03-herdr-under-dst.md`](NOTE-2026-09-03-herdr-under-dst.md) — an assessment, nothing
built. Its answer: herdr is the best-positioned extension in the tree for a DST profile, better than
compose, because its hook body performs every effect through `ExtPorts` and the deterministic world
already has every port it uses. What is missing is the profile itself plus a shared scripted-herdr
fake the two verify scripts hand-roll today.

## Facts worth not rediscovering

The 09-02 list still holds in full. Two to add:

- `git apply --check` failing on `reap-on-exit` and `allowed-kinds` means **applied**, not broken.
  Check `env` and the compose file before concluding a patch is pending.
- The contract leg skipping locally is not a regression and never has been. It needs
  `herdr plugin install aemrebarut/herdr-dagr --ref v0.3.1 --yes`, which this container's egress
  does not permit; CI is now where that leg actually runs.
