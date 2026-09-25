#!/usr/bin/env python3
"""The cgroup memory guard for heavy evaluator runs (ADR-004 D8 P2, PLAN-004 P2.1).

    scripts/eval/mem_guard.py --peak-bytes <n> --peak-source <text> [--record <path>]
                              [--interval <s>] [--kill-grace <s>] -- <command...>
    scripts/eval/mem_guard.py --verify <guard.json>

Why a guard: the machine's cgroup limit (`memory.max`, 24 GiB on the box the ADR
measured) is enforced by the kernel as an instantaneous OOM kill of whatever is
largest, which is usually not the run that grew. The handoff rule
(HANDOFF-2026-09-13, "`memory.current` must be well under 12 GiB or STOP") and
PLAN-004 §0.2 ("at most one heavy run at a time") are operator discipline; this
script is the enforceable form of both. Every real-segment replay, warm-up and
profiling run goes through it (ADR-004 D8 step 3; PLAN-004 P2.2, P3.1, P3.2,
P3.3, P5).

What it does, in order:

1. **Declared peak.** Every caller states the peak it expects, in bytes, and
   where the number came from (`--peak-source`, e.g. "P2.2 calibration, entry
   dev-1"). A missing or non-positive peak is a refusal.
2. **Exclusive.** `flock` on `$EVAL_LOCK_PATH` (default
   `.motoko/eval-corpus/.heavy.lock`, relative to the working directory). A
   second heavy run is refused (`lock_held`), never queued.
3. **Preflight** against `$EVAL_CGROUP_ROOT` (default `/sys/fs/cgroup`):
   - `memory.max` absent, malformed or zero: refused;
   - `memory.max` = `max` (unlimited): refused unless `EVAL_MEM_MAX_BYTES` is a
     positive decimal integer, which then stands in for the limit; any other
     value of that variable is refused (`override_invalid`);
   - `memory.current` >= 12 GiB: refused (`current_threshold`);
   - `current + peak + margin >= max` with a 2 GiB margin: refused (`headroom`).
4. **Monitor.** The command runs in its own session (so its whole process
   group is addressable). `memory.current` is sampled every `--interval`
   seconds (default 1). At `max - margin` the group gets SIGTERM, then SIGKILL
   after `--kill-grace` seconds (default 10), and the guard waits until the group
   is reaped. The guard makes itself the child subreaper, so orphaned
   grandchildren are reaped by it rather than left as zombies.
5. **Record.** `guard.json` (`--record`, default `./guard.json`) is written
   atomically (temp file + rename) on every exit path: pass, refusal, trip,
   early child exit, spawn failure, monitor start failure, interrupt.

Exit codes (distinct, so a caller can branch without parsing the record):

    0  EXIT_PASS          child exited 0; no trip; monitor healthy; group reaped
    1  EXIT_CHILD_FAILED  guard healthy, but the command failed (non-zero exit,
                          killed by a signal the guard did not send, or could
                          not be spawned); see `child` in the record
    3  EXIT_REFUSED       nothing was spawned: usage, lock, or preflight
    4  EXIT_TRIPPED       `memory.current` reached `max - margin`; the group was
                          terminated
    5  EXIT_INVALID       the run cannot be trusted: a monitor gap, a monitor
                          start failure, a guard interrupt, or a group that
                          would not reap

Callers treat `trip: true`, a non-empty `monitor.gaps`, or a missing record as
an invalid run (PLAN-004 §0.2). `verify_record()` / `--verify` implement that
rule in one place: accept only a record whose status is `pass`.

Self-tests (`scripts/eval/test_mem_guard.py`) point `EVAL_CGROUP_ROOT` and
`EVAL_LOCK_PATH` at scratch directories and grow a fake `memory.current`; they
never read the host cgroup or contend with a real heavy run.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import fcntl
import json
import os
import platform
import re
import signal
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

EXIT_PASS = 0
EXIT_CHILD_FAILED = 1
EXIT_REFUSED = 3
EXIT_TRIPPED = 4
EXIT_INVALID = 5

GIB = 1024 ** 3
CURRENT_THRESHOLD_BYTES = 12 * GIB  # the handoff rule: memory.current must be under this
MARGIN_BYTES = 2 * GIB  # PLAN-004 P2.1 default margin
DEFAULT_INTERVAL_SECONDS = 1.0
DEFAULT_KILL_GRACE_SECONDS = 10.0
GAP_FACTOR = 2.0  # a gap is > GAP_FACTOR * interval between consecutive samples
REAP_EXTRA_SECONDS = 5.0  # extra wait after SIGKILL before giving up on a group

DEFAULT_CGROUP_ROOT = "/sys/fs/cgroup"
DEFAULT_LOCK_PATH = ".motoko/eval-corpus/.heavy.lock"
DEFAULT_RECORD = "guard.json"
RECORD_VERSION = 1

PR_SET_CHILD_SUBREAPER = 36
DIGITS = re.compile(r"[0-9]+")
POLL_SECONDS = 0.05


# ------------------------------------------------------------------ small helpers


class UsageError(Exception):
    """A caller did not say what the guard needs; nothing is spawned."""


class MalformedValue(ValueError):
    def __init__(self, name: str, raw: str):
        super().__init__(f"{name}: {raw!r} is not a byte count")
        self.raw = raw


class _Parser(argparse.ArgumentParser):
    def error(self, message):  # argparse would sys.exit(2); we want a recorded refusal
        raise UsageError(message)


def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="milliseconds")


def build_parser() -> argparse.ArgumentParser:
    p = _Parser(
        prog="mem_guard.py",
        description="Run a heavy evaluator command under the cgroup memory guard.",
        epilog="The command follows a literal `--`. See the module docstring for the contract.",
    )
    p.add_argument("--peak-bytes", help="declared peak memory of the run, in bytes (required)")
    p.add_argument("--peak-source", help="where the declared peak comes from (required)")
    p.add_argument("--record", default=DEFAULT_RECORD, help=f"guard record path (default {DEFAULT_RECORD})")
    p.add_argument("--interval", type=float, default=DEFAULT_INTERVAL_SECONDS, help="sample interval, seconds")
    p.add_argument("--kill-grace", type=float, default=DEFAULT_KILL_GRACE_SECONDS, help="SIGTERM to SIGKILL, seconds")
    p.add_argument("--verify", metavar="RECORD", help="verify a guard record as a caller would, then exit")
    return p


def split_argv(argv):
    """Options before the first `--`, the command after it."""
    if "--" in argv:
        i = argv.index("--")
        return argv[:i], argv[i + 1 :], True
    return list(argv), [], False


def prescan_record_path(opts_argv) -> str:
    """The record path even when the rest of the options are unusable."""
    for i, a in enumerate(opts_argv):
        if a == "--record" and i + 1 < len(opts_argv):
            return opts_argv[i + 1]
        if a.startswith("--record="):
            return a[len("--record=") :]
    return DEFAULT_RECORD


def parse_peak(raw) -> int:
    if raw is None:
        raise UsageError("--peak-bytes is required: the declared peak of the run, in bytes")
    if not DIGITS.fullmatch(raw) or int(raw) <= 0:
        raise UsageError(f"--peak-bytes must be a positive integer number of bytes, got {raw!r}")
    return int(raw)


def parse_source(raw) -> str:
    if raw is None or not raw.strip():
        raise UsageError("--peak-source is required: where the declared peak comes from")
    return raw


# ---------------------------------------------------------------- cgroup reading


def read_cgroup_file(root: Path, name: str) -> str:
    return (root / name).read_text().strip()


def read_current(root: Path) -> int:
    """memory.current as an int. Module-level so the self-test can fail it on purpose."""
    raw = read_cgroup_file(root, "memory.current")
    if not DIGITS.fullmatch(raw):
        raise MalformedValue("memory.current", raw)
    return int(raw)


class Refusal:
    def __init__(self, reason: str, detail: str):
        self.reason = reason
        self.detail = detail


def preflight(env: dict, root: Path, peak: int, pre: dict):
    """Fill `pre` with what was read and return a Refusal, or None when the run may start."""
    pre["override_env"] = env.get("EVAL_MEM_MAX_BYTES")
    pre["override_applied"] = False
    max_path = root / "memory.max"
    try:
        raw = read_cgroup_file(root, "memory.max")
    except FileNotFoundError:
        return Refusal("max_absent", f"{max_path} does not exist")
    except OSError as e:
        return Refusal("max_unreadable", f"{max_path}: {e}")
    pre["memory_max_raw"] = raw
    if raw == "max":
        override = pre["override_env"]
        if override is None:
            return Refusal(
                "max_unlimited",
                f"{max_path} is 'max' (unlimited); set EVAL_MEM_MAX_BYTES to the limit to guard against",
            )
        if not DIGITS.fullmatch(override) or int(override) <= 0:
            return Refusal(
                "override_invalid",
                f"EVAL_MEM_MAX_BYTES must be a positive integer number of bytes, got {override!r}",
            )
        max_bytes = int(override)
        pre["override_applied"] = True
    elif DIGITS.fullmatch(raw):
        max_bytes = int(raw)
        if max_bytes == 0:
            pre["memory_max_bytes"] = 0
            return Refusal("max_zero", f"{max_path} is 0")
    else:
        return Refusal("max_malformed", f"{max_path}: {raw!r} is neither a byte count nor 'max'")
    pre["memory_max_bytes"] = max_bytes

    current_path = root / "memory.current"
    try:
        current = read_current(root)
    except FileNotFoundError:
        return Refusal("current_absent", f"{current_path} does not exist")
    except MalformedValue as e:
        pre["memory_current_raw"] = e.raw
        return Refusal("current_malformed", f"{current_path}: {e.raw!r} is not a byte count")
    except OSError as e:
        return Refusal("current_unreadable", f"{current_path}: {e}")
    pre["memory_current_bytes"] = current
    if current >= CURRENT_THRESHOLD_BYTES:
        return Refusal(
            "current_threshold",
            f"memory.current {current} >= {CURRENT_THRESHOLD_BYTES} (12 GiB); the handoff rule says STOP",
        )
    headroom = max_bytes - (current + peak + MARGIN_BYTES)
    pre["headroom_bytes"] = headroom
    if headroom <= 0:
        return Refusal(
            "headroom",
            f"current {current} + peak {peak} + margin {MARGIN_BYTES} >= max {max_bytes} (short by {-headroom})",
        )
    return None


# ------------------------------------------------------------------------- lock


def acquire_lock(path: Path):
    """Return a locked fd, or None when another heavy run holds the lock."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        return None
    try:
        os.ftruncate(fd, 0)
        os.write(fd, f"{os.getpid()}\n".encode())
    except OSError:
        pass  # the lock is what matters; the pid is a courtesy
    return fd


# ---------------------------------------------------------------- process groups


def set_subreaper(enable: bool) -> bool:
    try:
        import ctypes

        libc = ctypes.CDLL(None, use_errno=True)
        return libc.prctl(PR_SET_CHILD_SUBREAPER, 1 if enable else 0, 0, 0, 0) == 0
    except Exception:
        return False


def list_group_pids(pgid: int):
    """Every process (zombies included) whose process group is `pgid`."""
    found = []
    me = os.getpid()
    for entry in os.listdir("/proc"):
        if not entry.isdigit() or int(entry) == me:
            continue
        try:
            stat = Path("/proc", entry, "stat").read_text()
        except OSError:
            continue
        fields = stat.rsplit(")", 1)[1].split()
        if len(fields) > 2 and fields[2] == str(pgid):
            found.append(int(entry))
    return sorted(found)


def group_alive(pgid: int) -> bool:
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def reap_owned_group_members(pgid: int) -> None:
    """Reap, without blocking, every exited member of the group that is our child.

    Only called after the direct child has been reaped by Popen: `waitpid(-pgid)`
    would otherwise steal its status.
    """
    while True:
        try:
            pid, _ = os.waitpid(-pgid, os.WNOHANG)
        except ChildProcessError:
            return
        if pid == 0:
            return


def reap_group(pgid: int, deadline: float):
    """Wait until no process is left in the group, or the deadline passes."""
    while True:
        reap_owned_group_members(pgid)
        if not group_alive(pgid):
            return True, []
        if time.monotonic() >= deadline:
            return False, list_group_pids(pgid)
        time.sleep(0.02)


def killpg_quietly(pgid: int, sig: int) -> None:
    try:
        os.killpg(pgid, sig)
    except ProcessLookupError:
        pass


def terminate_group(proc: subprocess.Popen, pgid: int, grace: float, term: dict, clock) -> None:
    """SIGTERM the group, SIGKILL after `grace` seconds, wait until it is reaped."""
    term["signalled"] = True
    term["sigterm_at"] = clock()
    killpg_quietly(pgid, signal.SIGTERM)
    deadline = time.monotonic() + grace
    if proc.returncode is None:
        try:
            proc.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            pass
    reaped, residual = False, []
    if proc.returncode is not None:
        reaped, residual = reap_group(pgid, deadline)
    if not reaped:
        term["sigkill_at"] = clock()
        killpg_quietly(pgid, signal.SIGKILL)
        if proc.returncode is None:
            try:
                proc.wait(timeout=grace + REAP_EXTRA_SECONDS)
            except subprocess.TimeoutExpired:
                pass
        if proc.returncode is not None:
            reaped, residual = reap_group(pgid, time.monotonic() + grace + REAP_EXTRA_SECONDS)
        else:
            residual = list_group_pids(pgid) or [proc.pid]
    term["reaped"] = reaped
    term["residual_pids"] = residual


def reap_after_exit(proc: subprocess.Popen, pgid: int, grace: float, term: dict, clock) -> None:
    """The child exited on its own: anything it left behind in the group is terminated."""
    reap_owned_group_members(pgid)
    survivors = list_group_pids(pgid)
    term["survivors_after_child_exit"] = len(survivors)
    if survivors:
        terminate_group(proc, pgid, grace, term, clock)
    else:
        term["reaped"] = True
        term["residual_pids"] = []


# ---------------------------------------------------------------------- monitor


class Monitor:
    """Samples memory.current on a thread; the main thread acts on `tripped`."""

    def __init__(self, root: Path, interval: float, trip_threshold: int, clock):
        self.root = root
        self.interval = interval
        self.trip_threshold = trip_threshold
        self.clock = clock
        self.gap_threshold = interval * GAP_FACTOR
        self.samples = []  # [seconds since guard start, bytes]
        self.gaps = []
        self.peak = None
        self.peak_at = None
        self.tripped = threading.Event()
        self.tripped_at_bytes = None
        self.tripped_at = None
        self.stop = threading.Event()
        self.thread_error = None
        self._last_mono = None
        self.lock = threading.Lock()
        self.thread = threading.Thread(target=self._run, name="mem-guard-monitor", daemon=True)

    def sample(self) -> None:
        value = read_current(self.root)
        mono = time.monotonic()
        t = self.clock()
        with self.lock:
            if self._last_mono is not None and mono - self._last_mono > self.gap_threshold:
                self.gaps.append({"after_sample": len(self.samples) - 1, "seconds": round(mono - self._last_mono, 6)})
            self._last_mono = mono
            self.samples.append([t, value])
            if self.peak is None or value > self.peak:
                self.peak = value
                self.peak_at = t
            if value >= self.trip_threshold and not self.tripped.is_set():
                self.tripped_at_bytes = value
                self.tripped_at = t
                self.tripped.set()

    def _run(self) -> None:
        try:
            while not self.stop.wait(self.interval):
                try:
                    self.sample()
                except (OSError, ValueError) as e:
                    self._note_read_error(f"{type(e).__name__}: {e}")
        except Exception as e:  # a bug in the monitor is a monitor failure, not a pass
            self.thread_error = f"{type(e).__name__}: {e}"

    def _note_read_error(self, text: str) -> None:
        with self.lock:
            last = self.gaps[-1] if self.gaps else None
            if last and last.get("error") == text:
                last["count"] += 1
                last["last_at"] = self.clock()
            else:
                self.gaps.append({"at": self.clock(), "error": text, "count": 1})

    def snapshot(self, started: bool) -> dict:
        with self.lock:
            return {
                "started": started,
                "interval_seconds": self.interval,
                "gap_threshold_seconds": self.gap_threshold,
                "samples": [list(s) for s in self.samples],
                "sample_count": len(self.samples),
                "peak_bytes": self.peak,
                "peak_at_seconds": self.peak_at,
                "gaps": [dict(g) for g in self.gaps],
                "tripped_at_bytes": self.tripped_at_bytes,
                "tripped_at_seconds": self.tripped_at,
                "thread_error": self.thread_error,
            }


# ----------------------------------------------------------------------- record


def new_record(argv, record_path: Path) -> dict:
    return {
        "guard": {
            "version": RECORD_VERSION,
            "script": str(Path(__file__).resolve()),
            "pid": os.getpid(),
            "argv": list(argv),
            "cwd": os.getcwd(),
            "python": platform.python_version(),
            "hostname": socket.gethostname(),
            "subreaper": False,
        },
        "record_path": str(record_path),
        "status": None,
        "exit_code": None,
        "invalid_reason": None,
        "trip": False,
        "valid": False,
        "refusal": None,
        "declared": {"peak_bytes": None, "peak_source": None},
        "limits": {
            "current_threshold_bytes": CURRENT_THRESHOLD_BYTES,
            "margin_bytes": MARGIN_BYTES,
            "trip_threshold_bytes": None,
        },
        "cgroup": {"root": None, "current_path": None, "max_path": None},
        "preflight": {
            "memory_max_raw": None,
            "memory_max_bytes": None,
            "override_env": None,
            "override_applied": False,
            "memory_current_bytes": None,
            "headroom_bytes": None,
        },
        "lock": {"path": None, "resolved": None, "acquired": False},
        "command": [],
        "child": None,
        "monitor": {
            "started": False,
            "start_error": None,
            "interval_seconds": None,
            "gap_threshold_seconds": None,
            "samples": [],
            "sample_count": 0,
            "peak_bytes": None,
            "peak_at_seconds": None,
            "gaps": [],
            "tripped_at_bytes": None,
            "tripped_at_seconds": None,
            "thread_error": None,
            "ended_at": None,
        },
        "termination": {
            "kill_grace_seconds": None,
            "signalled": False,
            "sigterm_at": None,
            "sigkill_at": None,
            "reaped": False,
            "residual_pids": [],
            "survivors_after_child_exit": 0,
        },
        "interrupted": None,
        "started_at": now_iso(),
        "finished_at": None,
    }


def write_record(path: Path, rec: dict) -> None:
    """Temp file in the same directory, fsync, rename: readers see the old or the whole record."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(rec, f, indent=1, sort_keys=True)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    try:
        dfd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(dfd)
        finally:
            os.close(dfd)
    except OSError:
        pass


def finish(rec: dict, record_path: Path, status: str, code: int, invalid_reason=None, note: str = "") -> int:
    rec["status"] = status
    rec["exit_code"] = code
    rec["invalid_reason"] = invalid_reason
    rec["valid"] = status in ("pass", "child_failed")
    rec["finished_at"] = now_iso()
    try:
        write_record(record_path, rec)
        where = f"record={record_path}"
    except OSError as e:
        where = f"RECORD NOT WRITTEN ({e})"
        if code in (EXIT_PASS, EXIT_CHILD_FAILED):
            code = EXIT_INVALID  # a run without a record is not a result
    print(f"mem_guard: {status}{(' ' + note) if note else ''} {where}", file=sys.stderr)
    return code


def finish_refusal(rec: dict, record_path: Path, reason: str, detail: str) -> int:
    rec["refusal"] = {"reason": reason, "detail": detail}
    return finish(rec, record_path, "refused", EXIT_REFUSED, note=f"({reason}): {detail}")


def verify_record(path):
    """The caller's rule: accept only a complete, untripped, gap-free pass."""
    p = Path(path)
    if not p.exists():
        return False, "missing"
    try:
        rec = json.loads(p.read_text())
    except (OSError, ValueError):
        return False, "unreadable"
    if not isinstance(rec, dict):
        return False, "unreadable"
    if rec.get("trip", True) is not False:
        return False, "trip"
    mon = rec.get("monitor") or {}
    if mon.get("started") is not True:
        return False, "monitor_not_started"
    if mon.get("gaps", [None]):
        return False, "monitor_gap"
    if rec.get("interrupted") is not None:
        return False, "interrupted"
    if rec.get("valid") is not True:
        return False, "invalid"
    status = rec.get("status")
    if status != "pass":
        return False, f"status:{status}"
    return True, "pass"


# ------------------------------------------------------------------------- main


def install_handlers(interrupted: dict):
    if threading.current_thread() is not threading.main_thread():
        return {}
    previous = {}

    def on_signal(signum, _frame):
        interrupted.setdefault("signal", int(signum))

    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        previous[sig] = signal.signal(sig, on_signal)
    return previous


def restore_handlers(previous: dict) -> None:
    for sig, handler in previous.items():
        try:
            signal.signal(sig, handler)
        except (ValueError, OSError):
            pass


def child_status(proc: subprocess.Popen):
    rc = proc.returncode
    if rc is None:
        return None, None
    if rc < 0:
        return None, -rc
    return rc, None


def run_guarded(rec: dict, record_path: Path, command, root: Path, trip_threshold: int, interval: float, grace: float, clock) -> int:
    child = rec["child"] = {
        "pid": None,
        "pgid": None,
        "spawned_at": None,
        "exit_code": None,
        "signal": None,
        "spawn_error": None,
        "wall_seconds": None,
    }
    term = rec["termination"]
    interrupted: dict = {}
    rec["guard"]["subreaper"] = set_subreaper(True)
    previous = install_handlers(interrupted)
    monitor = None
    try:
        t_spawn = time.monotonic()
        try:
            proc = subprocess.Popen(command, start_new_session=True)
        except (OSError, ValueError) as e:
            child["spawn_error"] = f"{type(e).__name__}: {e}"
            return finish(rec, record_path, "child_failed", EXIT_CHILD_FAILED, note=f"(spawn failed: {e})")
        pgid = proc.pid
        child.update(pid=proc.pid, pgid=pgid, spawned_at=now_iso())

        monitor = Monitor(root, interval, trip_threshold, clock)
        try:
            monitor.sample()  # the first sample, synchronously: a monitor that cannot read does not start
            monitor.thread.start()
        except Exception as e:
            rec["monitor"]["start_error"] = f"{type(e).__name__}: {e}"
            terminate_group(proc, pgid, grace, term, clock)
            t_exit = time.monotonic()
            child["exit_code"], child["signal"] = child_status(proc)
            child["wall_seconds"] = round(t_exit - t_spawn, 6)
            rec["monitor"].update(monitor.snapshot(started=False))
            rec["monitor"]["ended_at"] = now_iso()
            rec["trip"] = monitor.tripped.is_set()
            return finish(rec, record_path, "invalid", EXIT_INVALID, "monitor_start_failed", note=f"(monitor start failed: {e})")
        rec["monitor"]["started"] = True

        reason = None
        while True:
            if proc.poll() is not None:
                break
            if monitor.tripped.is_set():
                reason = "trip"
                break
            if interrupted:
                reason = "interrupted"
                break
            if not monitor.thread.is_alive():
                reason = "monitor_died"
                break
            time.sleep(POLL_SECONDS)
        if reason is None:
            t_exit = time.monotonic()
            reap_after_exit(proc, pgid, grace, term, clock)
        else:
            terminate_group(proc, pgid, grace, term, clock)
            t_exit = time.monotonic()
        child["exit_code"], child["signal"] = child_status(proc)
        child["wall_seconds"] = round(t_exit - t_spawn, 6)

        monitor.stop.set()
        monitor.thread.join(timeout=interval * 2 + 1.0)
        rec["monitor"].update(monitor.snapshot(started=True))
        rec["monitor"]["ended_at"] = now_iso()
        rec["trip"] = monitor.tripped.is_set()
        rec["interrupted"] = {"signal": interrupted["signal"]} if interrupted else None

        peak = rec["monitor"]["peak_bytes"]
        if rec["trip"]:
            return finish(
                rec, record_path, "tripped", EXIT_TRIPPED,
                note=f"(memory.current {monitor.tripped_at_bytes} >= {trip_threshold}; group terminated, reaped={term['reaped']})",
            )
        if reason == "monitor_died":
            return finish(rec, record_path, "invalid", EXIT_INVALID, "monitor_died", note=f"({monitor.thread_error})")
        if interrupted:
            return finish(rec, record_path, "invalid", EXIT_INVALID, "interrupted", note=f"(signal {interrupted['signal']}; group terminated)")
        if rec["monitor"]["gaps"]:
            return finish(rec, record_path, "invalid", EXIT_INVALID, "monitor_gap", note=f"({len(rec['monitor']['gaps'])} gap(s); peak={peak})")
        if not term["reaped"]:
            return finish(rec, record_path, "invalid", EXIT_INVALID, "group_not_reaped", note=f"(residual pids {term['residual_pids']})")
        if child["exit_code"] != 0:
            what = f"exit {child['exit_code']}" if child["signal"] is None else f"signal {child['signal']}"
            return finish(rec, record_path, "child_failed", EXIT_CHILD_FAILED, note=f"({what}; peak={peak})")
        return finish(rec, record_path, "pass", EXIT_PASS, note=f"peak={peak} samples={rec['monitor']['sample_count']}")
    finally:
        restore_handlers(previous)
        if rec["guard"]["subreaper"]:
            set_subreaper(False)


def main(argv=None, env=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    env = dict(os.environ if env is None else env)
    t0 = time.monotonic()

    def clock() -> float:
        return round(time.monotonic() - t0, 6)

    opts_argv, command, _ = split_argv(argv)
    record_path = Path(prescan_record_path(opts_argv))
    rec = new_record(argv, record_path)
    try:
        ns = build_parser().parse_args(opts_argv)
    except UsageError as e:
        return finish_refusal(rec, record_path, "usage", str(e))

    if ns.verify is not None:
        ok, reason = verify_record(ns.verify)
        print(f"mem_guard: {'accept' if ok else 'reject'} {reason} {ns.verify}")
        return EXIT_PASS if ok else EXIT_INVALID

    record_path = Path(ns.record)
    rec["record_path"] = str(record_path)
    try:
        peak = parse_peak(ns.peak_bytes)
        source = parse_source(ns.peak_source)
        if not command:
            raise UsageError("the command to guard must follow a literal `--`")
        if not (ns.interval > 0):
            raise UsageError(f"--interval must be positive, got {ns.interval}")
        if ns.kill_grace < 0:
            raise UsageError(f"--kill-grace must not be negative, got {ns.kill_grace}")
    except UsageError as e:
        return finish_refusal(rec, record_path, "usage", str(e))

    rec["declared"] = {"peak_bytes": peak, "peak_source": source}
    rec["command"] = list(command)
    rec["monitor"]["interval_seconds"] = ns.interval
    rec["monitor"]["gap_threshold_seconds"] = ns.interval * GAP_FACTOR
    rec["termination"]["kill_grace_seconds"] = ns.kill_grace

    root = Path(env.get("EVAL_CGROUP_ROOT") or DEFAULT_CGROUP_ROOT)
    rec["cgroup"] = {
        "root": str(root),
        "current_path": str(root / "memory.current"),
        "max_path": str(root / "memory.max"),
    }
    lock_path = Path(env.get("EVAL_LOCK_PATH") or DEFAULT_LOCK_PATH)
    rec["lock"] = {"path": str(lock_path), "resolved": str(lock_path.resolve()), "acquired": False}
    try:
        lock_fd = acquire_lock(lock_path)
    except OSError as e:
        return finish_refusal(rec, record_path, "lock_unavailable", f"{lock_path}: {e}")
    if lock_fd is None:
        return finish_refusal(rec, record_path, "lock_held", f"another heavy run holds {lock_path}; refused, not queued")
    rec["lock"]["acquired"] = True
    try:
        refusal = preflight(env, root, peak, rec["preflight"])
        if refusal is not None:
            return finish_refusal(rec, record_path, refusal.reason, refusal.detail)
        trip_threshold = rec["preflight"]["memory_max_bytes"] - MARGIN_BYTES
        rec["limits"]["trip_threshold_bytes"] = trip_threshold
        return run_guarded(rec, record_path, command, root, trip_threshold, ns.interval, ns.kill_grace, clock)
    finally:
        os.close(lock_fd)


if __name__ == "__main__":
    sys.exit(main())
