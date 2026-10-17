# Probe results on AILANG v0.52.5

Date: 2026-10-17. AILANG **v0.52.5** (commit `7200786`), the version `ailang.lock` pins and
`ailang.toml` requires (`>=0.52.5`). GNU coreutils 9.4, Linux. Repo at `e69aaad7`.

ADR-001 D2 asks for a probe row on the pinned binary for every `ProcessError` arm rendered
`none`. The NOTE's §6.1 table and ADR §0's cases A to D were measured on v0.47.2. This file
repeats them on v0.52.5 and adds the two arms that had not been measured. Like the earlier
probes, these call `std/process.exec` directly. They do not go through `run_process_result` and
do not read the message the model gets.

## Cases 1-12: `exec_probe.sh`, unchanged

| # | Case | v0.52.5 returned | Effect | vs v0.47.2 |
|---|---|---|---|---|
| 1 | non-zero exit (control) | `Ok`, exit 3, 4 + 4 bytes | — | same |
| 2 | deadline, output already printed | `Err(Timeout(2002))` | the 8 bytes printed are gone | same |
| 3 | deadline, work still running | `Err(Timeout(7006))` | `m_late` absent at return, present 10 s later | same |
| 4 | over the output limit | `Err(OutputLimitExceeded(1000))` after 84 ms | `m_over` present | same |
| 5 | case 3 under `timeout -k 1 2` | `Ok`, exit 124, 8 + 8 bytes | `m_group` absent | same |
| 6 | case 5, child under `setsid` | `Ok`, exit 124, 8 bytes | `m_setsid` present | same |
| 7 | case 4 under `timeout -k 1 5` | `Err(OutputLimitExceeded(1000))` | `m_over2` present | same |
| 8 (A) | exit 0, child holds the pipe | `Err(SpawnFailed("exec: WaitDelay expired before I/O complete"))` after 5,070 ms | `m_fg` present at return; `m_bg` present later | same |
| 9 | case 8, child off the pipe | `Ok`, exit 0, 5 bytes | — | same |
| 10 (B) | no such command | `Err(NotFound(...))` | nothing ran | same |
| 11 (C) | file without the exec bit, by relative name | `Err(NotFound(./noexec.sh))` | marker absent | same |
| 12 (D) | command kills itself | `Err(AbnormalExit(9, killed))` | `m_sig` present | same |

`truncated` was `false` in every `Ok`; upstream passes `false` on every path.

One contrast, run separately: case 8 with `exit 7` in place of `exit 0` returns
`Ok`, exit 7, stdout `DONE`, after 5,076 ms. A held pipe turns only a **successful** exit into
`SpawnFailed`. Upstream: Go's `exec.ErrWaitDelay` is not an `*exec.ExitError`, so it reaches the
catch-all. Filed as sunholo-data/ailang#1879.

## Cases 13-21: `start_probe.sh`, new

`DEBUG_PROCESS=1` prints `[process] start` just before AILANG launches a process.

| # | Case | Returned | Launch trace | Did the target program run? |
|---|---|---|---|---|
| 13 | command not on `--process-allowlist` | `Err(NotAllowed(touch))` | none | no |
| 14 | subcommand chain does not match the allowlist | `Err(NotAllowed(bash))` | none | no |
| 15 | allowlisted absolute path, mode-644 script | `Err(PermissionDenied(path))` | `fork/exec …: permission denied` | no |
| 16 | allowlisted absolute path that is a directory | `Err(PermissionDenied(path))` | `fork/exec …: permission denied` | no |
| 17 | script whose `#!` interpreter is mode 644 | `Err(PermissionDenied(path))` | `fork/exec …: permission denied` | no |
| 18 | script with mode 111 (exec, no read) | `Ok`, exit 2, "cannot open … Permission denied" | started | yes, the interpreter ran |
| 19 | binary with mode 111 | `Ok`, exit 0 | started | yes |
| 20 | sandbox cwd with mode 600 | `Err(PermissionDenied(bash))` | `fork/exec /usr/bin/bash: permission denied` | no |
| 21 | sandbox cwd under a mode-000 parent | `Err(PermissionDenied(bash))` | `chdir …: permission denied` | no |

- **`NotAllowed` is refused before any launch** (13, 14). Reading the v0.52.5 source agrees: it
  comes only from the allowlist and `confine`, before `exec.CommandContext`. D2's rule for `none`
  is met, and the ruling of 2026-10-17 renders it `none`.
- **`PermissionDenied`: the target program never ran in any case produced.** A forked child
  existed for a moment in the `fork/exec` cases (15-17, 20). That is inferred from Go's error,
  not traced, because strace is not installed. Upstream assigns the arm by matching the text
  "permission denied" in the error of `cmd.Run()`, which merges start and wait errors, so nothing
  structural limits it to start failures. The ruling of 2026-10-17 renders it `unknown` until
  upstream states the guarantee (sunholo-data/ailang#1880).
- **Allowlist quirk:** an allowlisted absolute path skips the PATH lookup, so a mode-644 script
  is `PermissionDenied` (15) where by relative name it is `NotFound` (11).

## Upstream since v0.52.5

Read in the upstream source at v0.54.15, not run.

- **v0.54.14 (2026-10-16) kills the process group on timeout.** `exec` leads its own process
  group (`proctree.ConfigureContained`), except under a `--policy` owner, and Motoko does not pass
  `--policy`. After an upgrade, case 3's `m_late` should not land, and `Timeout` should return
  near the wall instead of the wall plus the 5 s WaitDelay (inferred). Children under `setsid`
  still escape, as in case 6. This was ADR D7 ask (b). For Motoko it becomes moving the pin to
  `>=0.54.14`, which is 012's to schedule.
- **Unchanged at v0.54.15:** the `ProcessError` arms and payloads, partial output on `Timeout` and
  `OutputLimitExceeded`, `OutputLimitExceeded` not stopping the command, case 8's `SpawnFailed`,
  and the substring match for `PermissionDenied`.

## Filed 2026-10-17 (ADR D7, ruled the same day)

| Ask | Issue |
|---|---|
| (a) partial stdout and stderr on `Timeout` and `OutputLimitExceeded`; the exit code of a command that finished past the limit | sunholo-data/ailang#1878 |
| (c) a clean exit whose pipe outlives it returns `Ok`, not `SpawnFailed` | sunholo-data/ailang#1879 |
| (d) which `ProcessError` arms are returned only before the program runs | sunholo-data/ailang#1880 |
