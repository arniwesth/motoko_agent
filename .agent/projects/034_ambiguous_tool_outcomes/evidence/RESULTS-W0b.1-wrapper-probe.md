# W0b.1: a deadline wrapper, probed through `run_process_result`

Task `034/PLAN-001/W0b.1`. Date: 2026-10-18. AILANG **v0.52.5** (commit `7200786`, the pin), GNU
coreutils 9.4, Linux aarch64 container, uid 1001 (not root). Repo at `5b275f24` (`origin/main`
after W0, #277, and #275, #278). Raw output: [`wrapper_probe.out`](wrapper_probe.out).

    bash .agent/projects/034_ambiguous_tool_outcomes/evidence/wrapper_probe.sh   # ~90 s, exit 0

## How this probe differs from the earlier ones

`exec_probe.sh` and `start_probe.sh` called `std/process.exec` directly. Here every case is one
`BashExec` or `RunTests` call that goes through `dispatch_one_typed` → `run_native_batch` →
`run_process_result` (`src/core/tool_runtime.ail:1017`). What the probe records is the tool
message from `tool_result_message`, the text the model reads, as W0.5's
`fault_disclosure_witness` does. The driver is [`wrapper_probe.ail`](wrapper_probe.ail). The script
copies it into a scratch tree that links the repo's `src/` and `packages/`, so no file under `src/`
or `scripts/` changes. The driver also times the dispatch with `now()`. That is the elapsed time a
harness-side rule would see.

The wrapper does not exist yet (W0b.3), so each case writes it into the call:

- **Direct-exec arm:** `cmd: "timeout"` and `args: ["-k","1","2", <argv>]`. With no shell tokens,
  `run_process_result` passes this to `exec` unchanged. This is exactly the shape W0b.3 would
  produce.
- **`bash -lc` arm:** a command string such as `timeout -k 1 2 bash -c '<cmd>'`.
  `run_process_result` turns that into `exec("bash", ["-lc", "timeout …"])`. Bash replaces itself
  with `timeout` (it execs the last simple command): case 46 shows `timeout`'s parent is `ailang`.
  So the process tree is the same as W0b.3's planned `timeout … bash -lc <cmd>`, with one extra
  `bash -c` level inside.

Unless a case says otherwise: deadline 2 s, grace (`-k`) 1 s, wall (`--process-timeout`) 20 s.
`S` is `echo PARTIAL; echo ERRLINE >&2`.

## Results

"Took" is the dispatch time the driver measured. "Rendered" is the message as the model reads it:
the `fault` object (kind and effects), then `exit_code`, `stdout` and `stderr`.

| # | Case | Wall | Took | Rendered | Effect |
|---|---|---|---|---|---|
| 22 | no wrapper, `bash -lc` arm: `S; (sleep 8; touch m22) & sleep 30` | 2 s | 7,005 ms | `deadline`/`unknown`, exit 1, stdout `""`, `timeout after 7004ms` | `m22` absent at render, **present** 10 s later |
| 23 | no wrapper, direct arm: `sleep 30` | 3 s | 3,004 | `deadline`/`unknown`, exit 1, stdout `""` | — |
| 24 | no wrapper: `echo OWN; exit 124` | 20 s | 4 | no fault, exit **124**, `OWN` | — |
| 25 | **wrapper deadline**: case 22's command under `timeout -k 1 2` | 20 s | 2,009 | **no fault**, exit **124**, stdout `PARTIAL`, stderr `ERRLINE` | `m25` **absent** 10 s later |
| 26 | wrapper, the command's own early `exit 124` | 20 s | 5 | no fault, exit **124**, `OWN` | — |
| 27 | wrapper, the command's own `exit 124` at 1.8 s | 20 s | 1,809 | no fault, exit **124**, `OWN` | — |
| 28 | wrapper `--verbose`, deadline | 20 s | 2,007 | no fault, exit 124, stderr `ERRLINE\ntimeout: sending signal TERM to command ‘bash’` | — |
| 29 | wrapper `--verbose`, the command prints that same line and exits 124 | 20 s | 3 | no fault, exit 124, stderr: the same line | — |
| 29b | case 28's deadline under `LC_ALL=C` | 20 s | 2,005 | stderr `… to command 'bash'` (ASCII quotes) | — |
| 30 | wrapper, the command ignores TERM (`trap "" TERM`) | 20 s | 3,005 | `signal`/`unknown`, signal 9, exit 1, stdout `""` | — |
| 31 | wrapper, the command handles TERM with `exit 3` | 20 s | 2,007 | no fault, exit **124**, `PARTIAL` | — |
| 46 | process groups under the wrapper | 20 s | 44 | the command's pgid = `timeout`'s pid; the runtime's pgid differs; `timeout`'s parent is `ailang` | — |
| 32 | no wrapper, direct arm: `tail -f tail.txt` | 3 s | 3,004 | `deadline`/`unknown`, stdout `""` | — |
| 33 | wrapper, direct arm: `timeout -k 1 2 tail -f tail.txt` | 20 s | 2,004 | no fault, exit 124, stdout `line one\nline two\n` | — |
| 34 | wrapper, direct arm: `timeout -k 1 2 sleep 30` | 20 s | 2,008 | no fault, exit 124 | — |
| 35 | direct-arm wrapper with an argument that holds a shell token: `timeout -k 1 2 sh -c 'echo A; sleep 30'` | 20 s | 3 | no fault, exit **125**, `Try 'timeout --help'`; `cmd` rendered as the full line | the call went to `bash -lc "timeout"`, and **its args were dropped** |
| 36 | direct arm, `PATH` without `timeout` | 20 s | 0 | `not_found`/`none`, `not found: timeout` | the command did not run |
| 37 | `bash -lc` arm, the wrapper binary absent (named `motoko-w0b-no-timeout`) | 20 s | 2 | **no fault**, exit **127**, `command not found` | `m37` absent: the command did not run |
| 38 | direct arm, `PATH` with only `gtimeout` | 20 s | 2,004 | no fault, exit 124 | — |
| 39 | case A, no wrapper: `echo DONE; touch m39fg; (sleep 9; touch m39bg) & exit 0` | 20 s | 5,009 | `spawn_failed`/`unknown`, stdout `""` | `m39fg` present at render; `m39bg` lands later |
| 40 | **case A under the wrapper** | 20 s | 5,007 | `spawn_failed`/`unknown`, stdout `""` (as 39) | `m40fg` present at render; `m40bg` **lands later** |
| 41 | case 40 with `exit 7` (#1879's contrast) | 20 s | 5,007 | no fault, exit 7, `DONE` | `m41bg` lands later |
| 42 | wrapper deadline 10 s **above** a 3 s wall | 3 s | 8,008 | `deadline`/`unknown`, stdout `""` | at render, `timeout` is gone and **the wrapped command is alive** (orphaned) |
| 43 | deadline 3 s under a 4 s wall, but deadline + grace (3 + 2 s) over it; TERM ignored | 4 s | 9,007 | `deadline`/`unknown`, stdout `""` | **the wrapped command is alive** at render and 10 s later |
| 44 | `RunTests`, wrapper deadline | 20 s | 2,006 | no fault, exit 124, `PARTIAL`/`ERRLINE` | — |
| 45 | wrapper deadline 5 s, but output passes a 1,000-byte limit first | 20 s | 6 | `output_limit`/`unknown`, bytes 1000, stdout `""` | `m45` present |

`truncated` was `false` in every message.

## The five open points

### 1. How a wrapper deadline is told apart from the command's own exit 124

From the rendered message, it cannot be. A wrapper deadline (25) and a command's own 124 (26, 27)
render the same `exit_code: 124` with no fault. W0b.3 has to add the distinction, and elapsed
time is the one signal that holds up.

- GNU `timeout` exits 124 whenever its timer fired, whatever the command did with the TERM
  (31: the command chose 3, the message says 124).
- If the command exits on its own before the timer, its 124 passes through.
- So "exit 124 and elapsed ≥ deadline" means the timer fired. The exception is a command that
  exits 124 on its own during the few milliseconds of dispatch overhead just before the deadline.
  Here the overhead was 0–6 ms (cases 24, 26, 36, 45). Wrapper deadlines returned at deadline +
  4–9 ms (25, 28, 33, 34, 38). A command's own 124 at 1.8 s returned at 1,809 ms (27).
- The only misreading is in that window: a command's own 124 rendered as `deadline`/`unknown`.
  That errs toward `unknown`, which P1 allows.

`--verbose` is not a usable signal. The command can forge the line (29), and its quoting depends on
the locale (28 against 29b). It would also add text to the `stderr` the model reads.

The cost of elapsed time is an effect. `run_process_result` is `! {Process}`. Reading a clock means
`Clock` in its row and up the chain: `run_native_batch` and `dispatch_one_typed` (`{FS, Process}`),
then `live_tool_outcome` (`ports.ail:1759`, `! {IO, Process, FS}`). W0b.3 has to size that, or find
another way to time the call.

A second case belongs to the same rule (30). If the command ignores TERM, `timeout` sends KILL to
its own process group when the grace runs out, and that group includes `timeout`. `exec` then
returns `AbnormalExit(9)` at deadline + grace. The message says `kind: signal`, not `deadline`, and
the partial output is lost. The effects are still `unknown`, so it is sound. To render it as
`deadline`, W0b.3 needs the rule "`AbnormalExit(9)` and elapsed ≥ deadline + grace".

### 2. Where GNU `timeout` is absent (stock macOS)

Not measured on macOS: no macOS host was available. Approximated three ways on Linux:

- **Direct arm, `PATH` without `timeout` (36).** `exec` returns `NotFound(timeout)` in 0 ms. The
  message is `not_found`/`none`, `not found: timeout`. The value is true, since nothing ran, but
  the model's command was not run and the message names a binary the model never asked for.
- **`bash -lc` arm, wrapper absent (37).** It renders as an ordinary exit 127 with no fault. The
  model's command did not run (`m37` absent). A model reading that would take it for its own
  command failing.
- **`gtimeout` only (38).** On macOS, Homebrew's coreutils installs GNU `timeout` as `gtimeout`.
  Called by that name it behaves as `timeout` does. Here it was the same binary, symlinked.

This also gives W0b.3 its fallback. Wrap at the `exec` level with `timeout` outermost. Then
`Err(NotFound(<wrapper name>))` means "the wrapper is absent", because a missing inner command
comes back from `timeout` as `Ok`, exit 127. Per D2 and cases 10–11, `NotFound` is returned before
any launch, so W0b.3 can retry the call unwrapped without running anything twice. Trying
`timeout` first and then `gtimeout` covers Homebrew.

Do not put the wrapper inside the `bash -lc` string. Absence then looks like 37, and that cannot be
told from a command's own 127.

Unmeasured on macOS:

- whether the runtime's `PATH` includes `/opt/homebrew/bin` when Motoko is launched;
- what `bash -l` does to `PATH` there (`path_helper`). Here `bash -l` turns `PATH=/nonexistent`
  into `/bin:/nonexistent:/usr/local/go/bin` (header of `wrapper_probe.out`). That is why `PATH`
  stripping cannot hide `/usr/bin/timeout` from the `bash -lc` arm on this host, and why 37 names a
  wrapper binary that does not exist instead.

### 3. The direct-exec arm

Without a wrapper, a direct-exec call such as `tail -f` (32) or `sleep 30` (23) hits the wall and
loses its output. Under `timeout` it returns at the deadline as `Ok` 124, with the output already
printed (33, 34). The wrapper works on this arm. It has to be applied to `effective`, after the arm
is chosen.

Case 35 is a defect this arm exposes. An argument containing a shell token (`;`, `|`, …) sends the
call to the `bash -lc` arm, which builds `wrapped_cmd` from `req.cmd` alone and drops `req.args`
(`tool_runtime.ail:1037`; ADR §7). What ran was `bash -lc "timeout"`, exit 125. The message still
renders `cmd` as the full line, so the model is told a command ran that did not. This is the
dropped-`req.args` item W0b.3 already owns. Case 35 shows it is a defect, not intended behaviour.

### 4. Case A under a wrapper

The wrapper does not help, as D6 expected, and now it is measured.

- `timeout` exits as soon as its direct child exits.
- A background child that still holds the pipe keeps `exec` waiting until `WaitDelay` runs out.
  The message is the same `spawn_failed`/`unknown` with stdout `""` as without the wrapper: 40
  against 39, both about 5,008 ms.
- `timeout` sends no signal when its child exits normally, so the background work is not stopped
  and lands later (`m40bg`).
- With `exit 7`, the wrapped call returns `Ok` 7 after the same 5 s (41), as #1879 describes.

Case A is upstream's, sunholo-data/ailang#1879.

### 5. What the wrapper adds under AILANG ≥0.54.14

Not measured: only v0.52.5 is installed. The shared checkout's `ailang/` is at v0.33.1-87 and has
no v0.54 tags. What follows combines the v0.52.5 rows above with `RESULTS-v0.52.5.md`'s reading of
the v0.54.15 source.

v0.54.14 kills the process group at the wall, so the group kill that case 25 has over case 22
(`m25` absent, `m22` present) goes away. Upstream should also return near the wall instead of at
the wall plus 5 s (inferred), so the wrapper's earlier return goes away too. Measured on v0.52.5,
the wrapper still adds:

- **The partial output.** Case 25 against 22, and 33 against 32. Unchanged upstream at v0.54.15:
  #1878 is open.
- **A deadline per call below the wall**, which is what `timeout_secs` would mean.
- **An `Ok` with an exit code.** That is how the output reaches the message on both arms,
  `RunTests` included (44).
- **TERM before KILL**, with a grace period. What signal the v0.54.14 runtime sends is not known
  here.

It does not add:

- anything for case A (40);
- anything for the output limit (45);
- anything for a child that calls `setsid` (case 6);
- output when the command ignores TERM (30).

**A hazard to carry into W0b.3, inferred and not run.** `timeout` moves itself and the command
into a new process group. Case 46: the command's pgid is `timeout`'s pid, not the runtime's. On
v0.52.5 the runtime kills only its direct child at the wall, so the command under `timeout` is
orphaned. Case 42 (the deadline above the wall) and case 43 (deadline + grace over the wall) both
leave it running past the result.

On v0.54.14, `exec` puts its child at the head of a new group and kills that group. If `timeout`
is that child, its `setpgid` changes nothing and the kill should still reach the command. If
`timeout` runs under some other process, for example inside `bash -lc "cd d && timeout …"`, where
bash forks instead of exec'ing, it forms a group of its own. The runtime's kill would then miss
the command, as `setsid` does.

So under either version W0b.3 needs `timeout` outermost, and a clamp that keeps
**deadline + grace** below the wall, not the deadline alone (43).

## For W0b.3, beyond the five points

- **`timeout_secs` has no field to land in.** `ProcessExecReq` (`types.ail:72-79`) has none, and
  `parse_exec_from_args` (`tool_runtime.ail:175`) does not read it. W0b.3 either adds the field,
  which is one type and six literals in `tool_runtime.ail` and means editing `types.ail`, outside
  the surface listed for Phase 0b, or reads it from the call's `args` in `run_native_call`
  (`:244-247`).
- **The wall is now readable from the core.** Since #275, `buildChildEnv` forwards
  `MOTOKO_PROCESS_TIMEOUT` to the runtime (`runtime-process.ts:553-557`). The value is a Go duration
  string. `""` means the 30 s default. `motoko-ext-herdr` already parses it. Reading it from
  `run_process_result` adds `Env` to the same effect chain as `Clock`.
- **`RunTests` arm.** A wrapper deadline renders today as an ordinary failing run, exit 124 with no
  fault (44). The `RunTestsResult` arm needs the same classification.

## Witness rows ws1–ws5 for W0b.4

W0b.3 adds these beside `fault_disclosure_witness`, run by `make world_state` with the same full
caps. They run in a scratch working directory and use the shapes measured above. Each row asserts
on the message from `tool_result_message(call, dispatch_one_typed(…).content)`. Deadlines are
`timeout_secs`. "Wall" is the `--process-timeout` of that `ailang run`. Each row's command uses a
sleep with a unique length, so the row can check with `pgrep` that nothing outlived it, and clean
up with `pkill -KILL`.

| Row | Kills | Call | Wall | Expected | What the mutant renders instead (measured shape) |
|---|---|---|---|---|---|
| ws1 | w1, the clamp | `BashExec` `echo PARTIAL; sleep 120.51`, `timeout_secs: 30` | 4 s | `fault.kind: deadline`, `effects: unknown`, stdout `PARTIAL\n`, the call returns in under 4 s, and `sleep 120.51` is gone afterwards | 42: `deadline` from the runtime after wall + 5 s, stdout `""`, the command still alive |
| ws2 | w2, 124 classification | `BashExec` `echo OWN; exit 124`, `timeout_secs: 10` | 20 s | **no `fault` key**, `exit_code: 124`, stdout `OWN\n` | 26 with a `fault` added: `deadline`/`unknown` |
| ws3 | w3, the absent-`timeout` fallback | `BashExec` `echo RAN; exit 3`, run with a `PATH` that holds `bash` and no `timeout` or `gtimeout` | 20 s | no `fault` key, `exit_code: 3`, stdout `RAN\n`, the same as W0 | 36: `not_found`/`none`, `not found: timeout`, exit 1; and if wrapped inside `bash -lc`, 37: exit 127 |
| ws4 | w4, a wrapper deadline is `unknown` | `BashExec` `echo PARTIAL; echo ERRLINE >&2; sleep 120.54`, `timeout_secs: 2` | 20 s | `fault.kind: deadline`, `effects: unknown`, `exit_code: 1` (D3: 1 on every faulted result) | `effects: none` |
| ws5 | w5, the captured output is kept | direct arm: `BashExec` `cmd: "tail"`, `args: ["-f", "tail.txt"]`, a two-line file, `timeout_secs: 2` | 20 s | `fault.kind: deadline`, `effects: unknown`, stdout `line one\nline two\n` | stdout `""`, the shape of 32 |

Notes on the rows:

- **ws3** needs the whole witness run under a stripped `PATH`, so it is its own `--entry` or its own
  `ailang run`. On this host `bash -l` prepends `/bin`, but `bash` is reached only through the
  wrapper's `exec`, and that is where `PATH` matters. If W0b.3 makes the wrapper's name
  configurable, ws3 can name a binary that does not exist instead.
- **ws1** asserts on stdout, so it kills a missing clamp whether the runtime then reports
  `Timeout`, as on v0.52.5, or kills the group, as on v0.54.14. A second, optional row with
  `trap "" TERM` and a grace that would cross the wall (43) checks that the clamp includes the
  grace.
- **ws4 and ws5** share a mechanism but kill different mutants: ws4 asserts the disclosure, ws5
  the output. ws5 also covers the direct-exec arm, so both arms have a row.
- **Survival:** ws2 and ws3 must stay green on unmutated source. A command's own 124 just inside
  the deadline (27) is a useful survival row only if W0b.3's margin is stated. A 1.8 s exit against
  a 2 s deadline left 190 ms here.

## What moved since the plan's grounding (`e69aaad7` → `5b275f24`)

Re-read at `5b275f24`, the commit this branch was cut from.

| Anchor | Plan says | At `5b275f24` | Moved by |
|---|---|---|---|
| `run_process_result` | `tool_runtime.ail:974-1025` | `:1017-1070` | W0 (#277): `fault` fields, `tool_fault` import, Search changes above it |
| delegated-backend refusal | `:987` | `:1030`, now `fault: refused_fault()` | W0.2 |
| the arm decision (`let effective`) | `:989-996` | `:1032-1039`, `wrapped_cmd` at `:1037`, unchanged | line shift |
| `exec(effective.cmd, effective.args)` | `:997` | `:1040` | line shift |
| `Err` arm: `RunTests`, `BashExec` | `:998-1019` (`:1000-1010`, `:1012-1019`) | `:1041-1064` (`:1043-1054`, `:1056-1064`), each now `fault: Some(process_fault(err))` | W0.2 |
| `Ok` arm | `:1020-1022` | `:1065-1067`, unchanged | line shift |
| `to_bash_result`, `to_test_result` | `:943`, `:956` | `:984`, `:998`, now `fault: None` | W0.2 |
| `process_error_to_string` | `:920` | `:961` | line shift |
| `shell_tokens_in_process` | `:107` | `:108` | line shift |
| `parse_exec_from_args` | `:174-187` | `:175-188`, unchanged; still no `timeout_secs` | line shift |
| `ProcessError` → kind and effects | — | new: `src/core/tool_fault.ail:167`, `:187`, `:271` (`Timeout` → `FaultDeadline`, `:175`) | W0.2 |
| `tool_catalog.ail` `timeout_secs` | `:55` | `:55`, unchanged. The description at `:54` was rewritten by W0.4 and now names the time limit | W0.4 (`502db43e`) |
| `runtime-process.ts` wall | `:1009-1022` | `:1014-1027` (comment and `processTimeoutArgs`) | #275 (`7f69ce20`): `MOTOKO_PROCESS_TIMEOUT` is now also forwarded to the child env at `:553-557` |
| `live_tool_outcome` | `ports.ail:1759` | `:1759`, unchanged | — |

NOTE §6.3 cites `runtime-process.ts:946-956` and `tool_runtime.ail:989-996` from an older
grounding (`4023bf08`). Both are superseded by the rows above.

## Not done, or not measured

- **AILANG ≥0.54.14: not run** (point 5). The analysis is inferred from the source reading in
  `RESULTS-v0.52.5.md`.
- **macOS: not run** (point 2). It was approximated by `PATH` stripping, a missing wrapper name and
  a `gtimeout` symlink. On macOS, `gtimeout` is Homebrew's build of the same coreutils, and its
  process-group behaviour is assumed to match (POSIX `setpgid`). Not checked.
- **The wrapper itself was not built.** That is W0b.3, and whether it goes ahead is W0b.2's
  question. Nothing under `src/` changed.
- **The probe ran as uid 1001.** No row depends on root.
- **Busybox or other `timeout` implementations: not tried.** Their `-k` and exit codes may differ.
