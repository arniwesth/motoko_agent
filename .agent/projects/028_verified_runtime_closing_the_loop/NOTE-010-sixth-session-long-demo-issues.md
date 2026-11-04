# NOTE-010 — sixth live session: long demo, issues found (2026-11-04)

Date: 2026-11-04. Profile: `default`. Task path: `Run a long demo of Motoko` →
`What is your impression of Motoko?` → this note. Shared checkout on `main`. No
tracked source was modified. One throwaway file (`scratchpad/long-demo-edit.txt`)
was created and deleted.

## 1. Session facts (measured)

- `MotokoRuntimeStatus` at step 4: `step_budget 1200`, `system_prefix` count 1,
  12307 chars, digest `sha256:f31ef76d…`. `context_limit 1000000`, source
  `bounded`/`catalogue`. Compaction counters all 0.
- Gates, run in the background, logs in `/tmp/motoko-long-demo/`:

| Target | Result | Wall time |
|---|---|---|
| `make check_core` | 61 passed, 0 failed | 145.5 s |
| `make verify_core` | 81 proven, 0 unstated, 1 blocked; 0 files failed, 43 bare; 79 substantive / 2 tautology / 1 unclassified | 38.0 s |
| `make corpus_pr` | PASS; 20/20 `CorpusRejection` constructors sampled; 34000 ms against a 180000 ms ceiling | 34.4 s |
| `make event_vocabulary` | PASS; 43 = 43 = 43 | 7.1 s |

- EditFile guards worked. `dry_run:true` returned a diff and `bytes_written: 0`.
  A wrong `expected_sha256` was refused (`expected_sha256 mismatch`, fault
  `refused`, effects `none`). The correct hash applied the edit.
- Delegate `mot-dlg-1793823472433` (claude, read-only research): correct,
  line-cited answer. It took at most 151.0 s end to end; the harness says 20–30 s
  is typical.

## 2. Issues

Ordered by how directly they undercut the project's claim that its status reports
can be trusted (ADR-001).

### I-1. The scratchpad summary says `verified` when the contract was `skipped`

An `ail` cell with a `requires`/`ensures` contract (`clamp_demo`, `verify:"auto"`,
`run:true`) printed:

```
[ailang] check: passed | verify: verified | committed: yes | ran: yes
  - clamp_demo: skipped
```

The summary and the per-function line disagree. The harness's own rule is that only
`verified` is a proof and `skipped` is not, so the summary overstates the result.
An agent that reads only the summary will report a proof that did not happen.
Expected: the summary is the weakest of the per-function statuses (here `skipped`),
or it names the mix. Cause not yet found: the scratchpad's status aggregation lives
in the scratchpad extension and was not read this session.

### I-2. BashExec reports `spawn_failed` for a command that ran

```
nohup bash -c '…make check_core … make event_vocabulary…' >/dev/null 2>&1 & echo started
```

returned `fault.kind: spawn_failed`, `effects: unknown`, stderr
`spawn failed: exec: WaitDelay expired before I/O complete`, and empty stdout
(`started` was lost). The process had in fact been spawned: `pgrep` showed
`make check_core` running, and all four targets later finished with exit 0.

`effects: unknown` is correct and prevented a duplicate run. The kind is wrong. The
error comes from the 5 s `cmd.WaitDelay` in `ailang/internal/effects/process.go`
(:125–130), which fires after the process exits while a pipe is still held open.
The most likely holder is the backgrounded child's inherited stdin, which was not
redirected; this is unconfirmed. Expected: a distinct kind such as
`io_wait_expired`, with the stdout captured before expiry kept.

### I-3. The 30 s process wall shapes every long task

A bounded poll (`for … sleep 10`) was killed at 30003 ms (`fault.kind: deadline`,
effects `unknown`). Every gate except `event_vocabulary` takes longer than 30 s:
`check_core` takes 145 s. So a session has to background, poll and re-poll by hand.
The Makefile already records the cause (the `demo_dst` comment, and
`.agent/issues/bashexec-timeout-knobs-are-dead.md`). This session confirms it is
still the default behaviour. `tools.process_timeout` exists per profile, but the
`default` profile does not raise it.

### I-4. The delegated backend is declared but not wired

`backend_for_v2` / `backend_for` (`tool_runtime.ail:1141`, `:212`) can select
`Delegated`. The Delegated arm only refuses
(`delegated_deferred_message`, `tool_phase.ail:217`,
`delegated_backend_not_wired:true`). `reject_if_ohmy_pi_unsupported`
(`rpc.ail:172`) stops the runtime at startup when `tools.ohmy_pi=true`, so the path
can never be reached. The project instructions still describe "HTTP between
runtime and env-server" as the protocol. Either wire the inbox wait, or mark the
path deferred in the protocol description and remove the dead selection logic.
This matches NOTE-009's lever "delete dead paths".

### I-5. `Search` scoped to a file puts line numbers in `path`

`Search{pattern:"^export func \\w+", dir:"src/core/rpc.ail"}` returned matches with
`path: "274"`, `"651"`, `"671"` and `line_number: 0`. The tool appears to pass
ripgrep's single-file output (`line:text`, no filename) through a parser that
expects `file:line:text`. Expected: `path` is the file and `line_number` is the
line, or the tool refuses a non-directory `dir`.

### I-6. Delegation output carries old session debris

Every `Delegate` result included two warnings: 30 stale in-flight records in other
sessions' dagr run files (panes `w1:*`, `w3:*`, `w4:*` that no longer exist), and 57
orphan scratch files in `.dagr/`. This is 4–5 KB of text per call, unrelated to the
task, all of it sent to the model. `HERDR_SWEEP_STALE=1` is offered but is not on by
default. Expected: one sweep, then a one-line count, or the warning only on the
first delegation of a session.

### I-7. Repository hygiene

- 1224 tracked `*.log` files and 2 tracked `.DS_Store` files
  (`git ls-files`).
- A loose patch at the root
  (`0001-docs-042-research-note-on-proving-harness-properties.patch`) and two
  alternative READMEs (`README_alternative_{1,2}.md`).
- The shared checkout is on `main` with uncommitted changes to tracked files
  (`.motoko/config/default/config.json`, `ailang.lock`, `bun.lock`,
  `package.json`, `scripts/verify_native_path_guard.ail`, …). `AGENTS.md` forbids
  this. It also blocks `make demo_dst` from being run safely here: that demo
  edits `src/core/session.ail`, so it has to run in a worktree.

### I-8. Speed

`check_core` took 145.5 s (cache state not measured). The delegate's round trip took up to
151 s, against the harness's own 20–30 s estimate. Neither is a correctness bug.
Together they make the verify-before-done rule (MANDATORY in the project
instructions) cost several minutes per edit.

### I-9. The TUI drops the GitHub token, and `gh` then reports "not logged in"

Found while opening this note's PR. The operator's shell exported `GH_TOKEN` and
`MOTOKO_BOT_GH_TOKEN`, and Motoko was started from that shell. Both variables are
present in `herdr`, the shell, `make motoko`, `run-agent.sh` and the TUI (`bun
src/tui/src/index.ts`). Both are absent from the `ailang run` runtime and from every
BashExec command (checked by name in `/proc/<pid>/environ`, never by value).

The cause is `buildChildEnv` (`src/tui/src/runtime-process.ts:499-676`). It builds
the runtime's environment from an explicit allowlist, and neither name is on it.
`gh auth status` inside the session then said "not logged in" and `git push`
failed with `could not read Username`. Both messages point at a missing login, not
at a filtered variable. This is the third time this allowlist has silently dropped
something; the egress proxy and `HERDR_*` are recorded in the same file.

Expected: forward `MOTOKO_BOT_GH_TOKEN` only (not `GH_TOKEN`, since
`tools/pr/README.md` says identity is never inherited), with a test like
`proxy-child-env.test.ts`. Or have the TUI print which allowlisted secrets it
dropped. Until then, the gitignored `.env` is the way to give a session the bot
token.

## 3. Not reproduced this session

- Lean scratchpad unavailable (no default elan toolchain). Recorded in
  `demo-artifacts/long-demo/artifact.md` from an earlier session; this session
  ran no Lean cell.

## 4. Suggested order

I-1, I-2, I-5 (status reports that contradict themselves or the facts; small, local
fixes), then I-9 (one allowlist entry and a test), I-4 (wire or delete), I-6, I-3,
I-7, I-8.
