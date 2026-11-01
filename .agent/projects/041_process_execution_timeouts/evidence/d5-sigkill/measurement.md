# D5's SIGKILL sentence: the measurement

This justifies the wording of ADR-002 D5's third bullet. No ruling depends on it: R10 still says SIGKILL
stays disclosed.

## Result

After a SIGKILL of the runtime, a command it was running:

- keeps running, and finishes its work if it does not write to stdout or stderr again;
- dies at its next write to either stream, with status 141 (128 + SIGPIPE), so later side effects do not happen;
- survives that write only if it ignores SIGPIPE. The write then fails and the command carries on. This is why
  D5 says "normally".

Without the kill, the same writes succeed and the command finishes, so the kill is what causes the death.

## Why this was re-measured

W2 (PR #293, branch `arniwesth/041-w2-setsid-probe`, read at `d308cdb8`) found this first, but kept no raw
output for it. I read its evidence files:

- `evidence/W2/base-probe.log`, `commit`, `mutants.tsv` and `mutate.sh` cover the surviving case only. None
  mentions SIGPIPE.
- `.agent/github/prs/origin-293/body.md` holds the only statement of the finding, and tests stdout only:
  "Measured once on this host: a command that later writes to stdout dies of SIGPIPE at that write, because its
  pipes died with the runtime. Its next file write never happened."

So the output below is my own, not W2's. It adds stderr, the exit status, an unkilled control and the
SIGPIPE-ignored case.

## What was run

AILANG v0.54.14 (commit `e1ef33f`), Linux 7.2.12-orbstack-00394-gbecdd6130068, `/bin/sh` is dash. Run on
2026-11-01, three rounds of nine cases, from a scratch directory. It has the same shape as W2's recipe: start
the runtime, wait until the command has started, send SIGKILL to the runtime's pid alone. No file in the
repository was changed to run it.

`probe.ail`:

```
module probe

import std/io (println)
import std/process (exec)

export func main() -> () ! {IO, Process} {
  let _ = exec("sh", ["-c", "printf up > \"$D/up\"; sleep 2; eval \"$AFTER\""]);
  println("returned without being killed")
}
```

`run.sh <kill|nokill> <case> <shell to run after the sleep>`:

```
mode=$1; name=$2; after=$3
d=$(mktemp -d)
D="$d" AFTER="$after" ailang run --caps IO,Process --process-timeout 30s --entry main probe.ail >"$d/log" 2>&1 & pid=$!
i=0; while [ ! -e "$d/up" ] && [ $i -lt 300 ]; do sleep 0.1; i=$((i+1)); done
at_kill=no; [ -e "$d/marker" ] && at_kill=yes
[ "$mode" = kill ] && kill -9 "$pid" 2>/dev/null
wait "$pid" 2>/dev/null; rs=$?
sleep 3.5
m=no; [ -e "$d/marker" ] && m=yes
st=-; [ -e "$d/status" ] && st=$(cat "$d/status")
echo "$name mode=$mode runtime_status=$rs up=$([ -e "$d/up" ] && echo yes || echo no) marker_at_kill=$at_kill marker_after=$m write_status=$st"
rm -rf "$d"
```

The cases, where `$M` is `printf done > "$D/marker"` and `$ST` is `echo $? > "$D/status"`:

| Case | Mode | Shell after the sleep |
|---|---|---|
| `no-write` | kill | `$M` |
| `stdout-direct` | kill | `printf x; $M` |
| `stderr-direct` | kill | `printf x >&2; $M` |
| `stdout-status` | kill | `(printf x); $ST; $M` |
| `stderr-status` | kill | `(printf x >&2); $ST; $M` |
| `stdout-ignored` | kill | `trap '' PIPE; printf x; $ST; $M` |
| `stderr-ignored` | kill | `trap '' PIPE; printf x >&2; $ST; $M` |
| `stdout-control` | nokill | `printf x; $M` |
| `stderr-control` | nokill | `printf x >&2; $M` |

The `-status` cases write in a subshell, so the outer shell lives to record how the write ended. Their
`marker_after=yes` is the outer shell, not the process that wrote.

## What was observed

All three rounds printed the same lines for each case. Round one, verbatim:

```
no-write mode=kill runtime_status=137 up=yes marker_at_kill=no marker_after=yes write_status=-
stdout-direct mode=kill runtime_status=137 up=yes marker_at_kill=no marker_after=no write_status=-
stderr-direct mode=kill runtime_status=137 up=yes marker_at_kill=no marker_after=no write_status=-
stdout-status mode=kill runtime_status=137 up=yes marker_at_kill=no marker_after=yes write_status=141
stderr-status mode=kill runtime_status=137 up=yes marker_at_kill=no marker_after=yes write_status=141
stdout-ignored mode=kill runtime_status=137 up=yes marker_at_kill=no marker_after=yes write_status=1
stderr-ignored mode=kill runtime_status=137 up=yes marker_at_kill=no marker_after=yes write_status=1
stdout-control mode=nokill runtime_status=0 up=yes marker_at_kill=no marker_after=yes write_status=-
stderr-control mode=nokill runtime_status=0 up=yes marker_at_kill=no marker_after=yes write_status=-
```

Not tested: other shells and non-shell commands, a command holding a dup of the pipe's read end (no ordinary
child has one), and macOS.

## W2's probe, which pins the surviving case

`evidence/W2/base-probe.log` on W2's branch:

```
SIGKILL: runtime_status=137 command_started=yes marker_at_kill=no marker_after=yes marker_ms_after_kill~1900
OK: SIGKILL: the runtime died of the signal
OK: SIGKILL: the command had started and not finished when the signal was sent
OK: SIGKILL: the command survived and wrote its marker
```

The command behind those rows, in `scripts/verify_native_process_sigkill.ail`, writes only to files after the
kill, so it is the `no-write` case above:

```
exec("sh", ["-c", "printf up > \"$PROBE_SIGKILL_DIR/up\"; sleep 2; printf survived > \"$PROBE_SIGKILL_DIR/marker\""])
```

No row pins the SIGPIPE case. Whether to add one is a separate decision.

## The operator documentation

W2's `docs/configuration.md`, not yet on `main`, already says this:

> - **SIGKILL of the runtime.** The runtime cannot clean up after a SIGKILL, so a
>   command it was running keeps running and its side effects still happen. Its
>   stdout and stderr pipes died with the runtime, so its next write to them
>   normally ends it with SIGPIPE.
>
> `make verify_native_process_tree` pins the survival in both cases.

D5's new wording uses the same terms and the measurement above supports both. Until #293 merges, the
documentation and the row that D5 cites are not on `main`.
