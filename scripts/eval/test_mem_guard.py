"""Tests for the cgroup memory guard (ADR-004 D8 P2, PLAN-004 P2.1).

Every test runs against a scratch cgroup root and a scratch lock path
(`EVAL_CGROUP_ROOT`, `EVAL_LOCK_PATH`), so nothing here reads the host's
`/sys/fs/cgroup` or contends with a real heavy run. "Synthetic growth" is the
child (or the test) writing a larger number into the scratch `memory.current`.

Two-sided where it matters: every refusal is shown to refuse with its named
reason, and the same fixture with the fault removed is shown to pass.

Run: python3 -m pytest scripts/eval/test_mem_guard.py
"""

from __future__ import annotations

import fcntl
import itertools
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
GUARD = HERE / "mem_guard.py"
sys.path.insert(0, str(HERE))

import mem_guard  # noqa: E402

GIB = 1024 ** 3
# Values from the plan: 12 GiB current threshold, 2 GiB margin.
THRESHOLD = 12 * GIB
MARGIN = 2 * GIB

# A comfortable, healthy scratch cgroup: 1 GiB used of 8 GiB, so with a 1 GiB
# declared peak the headroom check is 1 + 1 + 2 = 4 < 8 and the trip line is 6 GiB.
HEALTHY_CURRENT = 1 * GIB
HEALTHY_MAX = 8 * GIB
PEAK = 1 * GIB
TRIP_LINE = HEALTHY_MAX - MARGIN
ABOVE_TRIP = TRIP_LINE + GIB // 2

FAST = ["--interval", "0.05", "--kill-grace", "0.5"]


# --------------------------------------------------------------------------- helpers


def write_cgroup(root: Path, current, maximum) -> None:
    root.mkdir(parents=True, exist_ok=True)
    if current is not None:
        (root / "memory.current").write_text(f"{current}\n")
    if maximum is not None:
        (root / "memory.max").write_text(f"{maximum}\n")


class Run:
    def __init__(self, proc: subprocess.CompletedProcess, record_path: Path):
        self.proc = proc
        self.record_path = record_path
        self.record = json.loads(record_path.read_text()) if record_path.exists() else None

    @property
    def code(self) -> int:
        return self.proc.returncode


def guard_env(tmp_path: Path, **extra) -> dict:
    env = dict(os.environ)
    env.pop("EVAL_MEM_MAX_BYTES", None)
    env["EVAL_CGROUP_ROOT"] = str(tmp_path / "cg")
    env["EVAL_LOCK_PATH"] = str(tmp_path / "lock" / ".heavy.lock")
    env.update({k: str(v) for k, v in extra.items()})
    return env


def run_guard(
    tmp_path: Path,
    command,
    *,
    current=HEALTHY_CURRENT,
    maximum=HEALTHY_MAX,
    peak=PEAK,
    source="test-declared",
    env=None,
    extra_args=(),
    omit=(),
    timeout=30,
) -> Run:
    """Run the guard as a subprocess against a scratch cgroup and return the outcome."""
    root = tmp_path / "cg"
    write_cgroup(root, current, maximum)
    env = env or guard_env(tmp_path)
    record = tmp_path / "rec" / "guard.json"
    argv = [sys.executable, str(GUARD), "--record", str(record)]
    if "peak-bytes" not in omit:
        argv += ["--peak-bytes", str(peak)]
    if "peak-source" not in omit:
        argv += ["--peak-source", source]
    argv += FAST + list(extra_args)
    if "command" not in omit:
        argv += ["--", *command]
    proc = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=timeout)
    run = Run(proc, record)
    assert_no_temp_files(record.parent)
    return run


def assert_no_temp_files(directory: Path) -> None:
    """Atomic write: the record directory holds the record and nothing half-written."""
    if not directory.exists():
        return
    leftovers = [p.name for p in directory.iterdir() if p.name != "guard.json"]
    assert leftovers == [], leftovers


def assert_complete_record(rec: dict) -> None:
    """The keys every exit path must leave behind, regardless of outcome."""
    for key in (
        "status",
        "exit_code",
        "trip",
        "valid",
        "refusal",
        "declared",
        "limits",
        "cgroup",
        "preflight",
        "lock",
        "command",
        "child",
        "monitor",
        "termination",
        "interrupted",
        "started_at",
        "finished_at",
    ):
        assert key in rec, f"record lacks {key!r}"
    assert rec["limits"]["margin_bytes"] == MARGIN
    assert rec["limits"]["current_threshold_bytes"] == THRESHOLD
    assert isinstance(rec["trip"], bool)
    assert isinstance(rec["valid"], bool)


def assert_refused(run: Run, reason: str) -> None:
    assert run.code == mem_guard.EXIT_REFUSED, (run.code, run.proc.stderr)
    assert run.record is not None, "a refusal must still leave a record"
    assert_complete_record(run.record)
    rec = run.record
    assert rec["status"] == "refused"
    assert rec["refusal"]["reason"] == reason, rec["refusal"]
    assert rec["trip"] is False
    assert rec["valid"] is False
    assert rec["child"] is None, "a refusal spawns nothing"
    assert rec["monitor"]["started"] is False
    assert reason in run.proc.stderr


def pid_gone(pid: int) -> bool:
    """True when the pid is gone or reaped; a zombie counts as not gone."""
    try:
        stat = Path(f"/proc/{pid}/stat").read_text()
    except FileNotFoundError:
        return True
    state = stat.rsplit(")", 1)[1].split()[0]
    return state == "X"


def wait_for(predicate, timeout=5.0, step=0.02):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(step)
    return predicate()


# ---------------------------------------------------------------- preflight refusals


def test_refuses_current_at_or_above_12_gib(tmp_path):
    run = run_guard(tmp_path, ["true"], current=13 * GIB, maximum=24 * GIB)
    assert_refused(run, "current_threshold")
    assert run.record["preflight"]["memory_current_bytes"] == 13 * GIB
    # Exactly the threshold refuses too (>=).
    run = run_guard(tmp_path, ["true"], current=THRESHOLD, maximum=24 * GIB)
    assert_refused(run, "current_threshold")


def test_refuses_without_headroom(tmp_path):
    # 1 + 2 + 2 = 5 >= 4: refused even though current is far below 12 GiB.
    run = run_guard(tmp_path, ["true"], current=1 * GIB, maximum=4 * GIB, peak=2 * GIB)
    assert_refused(run, "headroom")
    assert run.record["preflight"]["headroom_bytes"] == 4 * GIB - (1 * GIB + 2 * GIB + MARGIN)
    # Exactly equal refuses (>=); one byte of headroom passes.
    run = run_guard(tmp_path, ["true"], current=1 * GIB, maximum=5 * GIB, peak=2 * GIB)
    assert_refused(run, "headroom")
    run = run_guard(tmp_path, ["true"], current=1 * GIB, maximum=5 * GIB + 1, peak=2 * GIB)
    assert run.code == mem_guard.EXIT_PASS, run.proc.stderr


def test_refuses_absent_memory_max(tmp_path):
    run = run_guard(tmp_path, ["true"], maximum=None)
    assert_refused(run, "max_absent")


def test_refuses_absent_memory_current(tmp_path):
    run = run_guard(tmp_path, ["true"], current=None)
    assert_refused(run, "current_absent")


@pytest.mark.parametrize("raw", ["lots", "", "12 GiB", "1e9", "-1", "0x10", "max max"])
def test_refuses_malformed_memory_max(tmp_path, raw):
    run = run_guard(tmp_path, ["true"], maximum=raw)
    assert_refused(run, "max_malformed")
    assert run.record["preflight"]["memory_max_raw"] == raw


def test_refuses_malformed_memory_current(tmp_path):
    run = run_guard(tmp_path, ["true"], current="soon")
    assert_refused(run, "current_malformed")


def test_refuses_zero_memory_max(tmp_path):
    run = run_guard(tmp_path, ["true"], maximum=0)
    assert_refused(run, "max_zero")


def test_refuses_unlimited_memory_max_without_override(tmp_path):
    run = run_guard(tmp_path, ["true"], maximum="max")
    assert_refused(run, "max_unlimited")
    assert run.record["preflight"]["override_env"] is None


@pytest.mark.parametrize("raw", ["abc", "-5", "0", "1.5", "", " 8589934592", "8589934592\n", "+1", "inf", "1e9", "0x20"])
def test_refuses_bad_override(tmp_path, raw):
    env = guard_env(tmp_path, EVAL_MEM_MAX_BYTES=raw)
    run = run_guard(tmp_path, ["true"], maximum="max", env=env)
    assert_refused(run, "override_invalid")
    assert run.record["preflight"]["override_env"] == raw
    assert run.record["preflight"]["override_applied"] is False


def test_good_override_replaces_unlimited_max(tmp_path):
    env = guard_env(tmp_path, EVAL_MEM_MAX_BYTES=8 * GIB)
    run = run_guard(tmp_path, ["true"], maximum="max", env=env)
    assert run.code == mem_guard.EXIT_PASS, run.proc.stderr
    pre = run.record["preflight"]
    assert pre["memory_max_raw"] == "max"
    assert pre["memory_max_bytes"] == 8 * GIB
    assert pre["override_applied"] is True
    assert run.record["limits"]["trip_threshold_bytes"] == 8 * GIB - MARGIN


def test_override_is_ignored_when_max_is_finite(tmp_path):
    env = guard_env(tmp_path, EVAL_MEM_MAX_BYTES="garbage")
    run = run_guard(tmp_path, ["true"], env=env)
    assert run.code == mem_guard.EXIT_PASS, run.proc.stderr
    assert run.record["preflight"]["override_applied"] is False
    assert run.record["preflight"]["memory_max_bytes"] == HEALTHY_MAX


# ---------------------------------------------------------------------- usage refusals


def test_refuses_without_declared_peak(tmp_path):
    run = run_guard(tmp_path, ["true"], omit=("peak-bytes",))
    assert_refused(run, "usage")
    assert "peak-bytes" in run.record["refusal"]["detail"]


def test_refuses_without_peak_source(tmp_path):
    run = run_guard(tmp_path, ["true"], omit=("peak-source",))
    assert_refused(run, "usage")
    run = run_guard(tmp_path, ["true"], source="   ")
    assert_refused(run, "usage")


@pytest.mark.parametrize("peak", ["0", "-1", "1.5", "abc", "1e9"])
def test_refuses_non_positive_or_non_integer_peak(tmp_path, peak):
    run = run_guard(tmp_path, ["true"], peak=peak)
    assert_refused(run, "usage")


def test_refuses_without_command(tmp_path):
    run = run_guard(tmp_path, [], omit=("command",))
    assert_refused(run, "usage")
    run = run_guard(tmp_path, [])
    assert_refused(run, "usage")


def test_usage_refusal_writes_record_at_default_path(tmp_path):
    """No --record: the record still lands, at ./guard.json in the working directory."""
    root = tmp_path / "cg"
    write_cgroup(root, HEALTHY_CURRENT, HEALTHY_MAX)
    proc = subprocess.run(
        [sys.executable, str(GUARD), "--peak-source", "x", "--", "true"],
        env=guard_env(tmp_path),
        cwd=tmp_path,
        capture_output=True,
        text=True,
    )
    assert proc.returncode == mem_guard.EXIT_REFUSED
    rec = json.loads((tmp_path / "guard.json").read_text())
    assert rec["refusal"]["reason"] == "usage"


# ----------------------------------------------------------------------- lock contention


def test_refuses_when_lock_is_held(tmp_path):
    lock_path = tmp_path / "lock" / ".heavy.lock"
    lock_path.parent.mkdir(parents=True)
    fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o644)
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    try:
        run = run_guard(tmp_path, ["true"])
        assert_refused(run, "lock_held")
        assert run.record["lock"]["path"] == str(lock_path)
        assert run.record["lock"]["acquired"] is False
    finally:
        os.close(fd)
    # Released: the same invocation now passes and the lock file carries the guard's pid.
    run = run_guard(tmp_path, ["true"])
    assert run.code == mem_guard.EXIT_PASS, run.proc.stderr
    assert run.record["lock"]["acquired"] is True
    assert lock_path.exists()


def test_second_heavy_run_is_refused_not_queued(tmp_path):
    """Two guards, one lock: the second is refused immediately while the first still runs."""
    root = tmp_path / "cg"
    write_cgroup(root, HEALTHY_CURRENT, HEALTHY_MAX)
    env = guard_env(tmp_path)
    rec1 = tmp_path / "r1" / "guard.json"
    rec2 = tmp_path / "r2" / "guard.json"
    base = [sys.executable, str(GUARD), "--peak-bytes", str(PEAK), "--peak-source", "t", *FAST]
    first = subprocess.Popen(base + ["--record", str(rec1), "--", "sleep", "3"], env=env)
    try:
        assert wait_for(lambda: rec1.parent.exists() or first.poll() is not None, timeout=2) or True
        # Give the first guard time to take the lock before the second tries.
        time.sleep(0.4)
        t0 = time.monotonic()
        second = subprocess.run(
            base + ["--record", str(rec2), "--", "true"], env=env, capture_output=True, text=True
        )
        elapsed = time.monotonic() - t0
        assert second.returncode == mem_guard.EXIT_REFUSED, second.stderr
        assert elapsed < 2.0, "the second run must be refused, not queued behind the first"
        rec = json.loads(rec2.read_text())
        assert rec["refusal"]["reason"] == "lock_held"
        assert first.poll() is None, "refusing the second run must not disturb the first"
    finally:
        first.terminate()
        first.wait(timeout=10)


# ------------------------------------------------------------------------------- trips


def test_trip_on_synthetic_growth_reaps_the_process_group(tmp_path):
    cur = tmp_path / "cg" / "memory.current"
    gc_pid_file = tmp_path / "grandchild.pid"
    # The child forks a grandchild, then grows the (scratch) cgroup past the trip line.
    script = (
        "sleep 30 & echo $! > \"$GC_PID\"; sleep 0.3; "
        "echo \"$ABOVE\" > \"$CUR\"; wait"
    )
    env = guard_env(tmp_path, GC_PID=gc_pid_file, CUR=cur, ABOVE=ABOVE_TRIP)
    run = run_guard(tmp_path, ["sh", "-c", script], env=env)
    assert run.code == mem_guard.EXIT_TRIPPED, run.proc.stderr
    rec = run.record
    assert_complete_record(rec)
    assert rec["status"] == "tripped"
    assert rec["trip"] is True
    assert rec["valid"] is False
    assert rec["monitor"]["peak_bytes"] >= TRIP_LINE
    assert rec["monitor"]["tripped_at_bytes"] == ABOVE_TRIP
    assert rec["termination"]["signalled"] is True
    assert rec["termination"]["sigterm_at"] is not None
    assert rec["termination"]["sigkill_at"] is None, "SIGTERM was enough; no SIGKILL expected"
    assert rec["termination"]["reaped"] is True
    assert rec["termination"]["residual_pids"] == []
    assert rec["child"]["signal"] == signal.SIGTERM
    grandchild = int(gc_pid_file.read_text())
    assert pid_gone(rec["child"]["pid"])
    assert pid_gone(grandchild), "the grandchild must be gone (not a zombie) once the guard returns"


def test_trip_escalates_to_sigkill_when_sigterm_is_ignored(tmp_path):
    cur = tmp_path / "cg" / "memory.current"
    script = "trap '' TERM; sleep 0.3; echo \"$ABOVE\" > \"$CUR\"; sleep 30"
    env = guard_env(tmp_path, CUR=cur, ABOVE=ABOVE_TRIP)
    t0 = time.monotonic()
    run = run_guard(tmp_path, ["sh", "-c", script], env=env)
    elapsed = time.monotonic() - t0
    assert run.code == mem_guard.EXIT_TRIPPED, run.proc.stderr
    rec = run.record
    assert rec["trip"] is True
    assert rec["termination"]["sigterm_at"] is not None
    assert rec["termination"]["sigkill_at"] is not None
    assert rec["termination"]["sigkill_at"] >= rec["termination"]["sigterm_at"] + 0.5
    assert rec["termination"]["reaped"] is True
    assert rec["termination"]["residual_pids"] == []
    assert rec["child"]["signal"] == signal.SIGKILL
    assert pid_gone(rec["child"]["pid"])
    assert elapsed < 10, "the kill grace is the flag's 0.5 s, not the default 10 s"


def test_trip_line_is_max_minus_margin(tmp_path):
    """One byte under the line does not trip; the line itself does (>=)."""
    cur = tmp_path / "cg" / "memory.current"
    env = guard_env(tmp_path, CUR=cur, VALUE=TRIP_LINE - 1)
    run = run_guard(tmp_path, ["sh", "-c", "echo \"$VALUE\" > \"$CUR\"; sleep 0.4"], env=env)
    assert run.code == mem_guard.EXIT_PASS, run.proc.stderr
    assert run.record["trip"] is False
    assert run.record["monitor"]["peak_bytes"] == TRIP_LINE - 1
    env = guard_env(tmp_path, CUR=cur, VALUE=TRIP_LINE)
    run = run_guard(tmp_path, ["sh", "-c", "echo \"$VALUE\" > \"$CUR\"; sleep 30"], env=env)
    assert run.code == mem_guard.EXIT_TRIPPED, run.proc.stderr
    assert run.record["trip"] is True


# ------------------------------------------------------------------- clean and early exits


def test_child_that_exits_immediately_leaves_a_complete_record(tmp_path):
    run = run_guard(tmp_path, ["true"])
    assert run.code == mem_guard.EXIT_PASS, run.proc.stderr
    rec = run.record
    assert_complete_record(rec)
    assert rec["status"] == "pass"
    assert rec["trip"] is False
    assert rec["valid"] is True
    assert rec["refusal"] is None
    assert rec["child"]["exit_code"] == 0
    assert rec["child"]["signal"] is None
    assert rec["child"]["pid"] > 0
    assert rec["child"]["pgid"] == rec["child"]["pid"]
    assert rec["monitor"]["started"] is True
    assert rec["monitor"]["sample_count"] >= 1
    assert len(rec["monitor"]["samples"]) == rec["monitor"]["sample_count"]
    assert rec["monitor"]["peak_bytes"] == HEALTHY_CURRENT
    assert rec["monitor"]["gaps"] == []
    assert rec["termination"]["signalled"] is False
    assert rec["termination"]["reaped"] is True
    assert rec["declared"] == {"peak_bytes": PEAK, "peak_source": "test-declared"}
    assert rec["command"] == ["true"]
    assert rec["lock"]["acquired"] is True


def test_clean_exit_records_trip_false_and_samples(tmp_path):
    run = run_guard(tmp_path, ["sleep", "0.4"])
    assert run.code == mem_guard.EXIT_PASS, run.proc.stderr
    rec = run.record
    assert rec["trip"] is False
    assert rec["valid"] is True
    samples = rec["monitor"]["samples"]
    assert len(samples) >= 4, samples
    times = [s[0] for s in samples]
    assert times == sorted(times)
    assert all(s[1] == HEALTHY_CURRENT for s in samples)
    assert rec["monitor"]["gaps"] == []
    assert rec["child"]["wall_seconds"] >= 0.35


def test_child_failure_is_reported_without_a_trip(tmp_path):
    run = run_guard(tmp_path, ["sh", "-c", "exit 7"])
    assert run.code == mem_guard.EXIT_CHILD_FAILED, run.proc.stderr
    rec = run.record
    assert rec["status"] == "child_failed"
    assert rec["child"]["exit_code"] == 7
    assert rec["trip"] is False
    assert rec["valid"] is True, "the measurement is sound even though the command failed"


def test_child_killed_by_its_own_signal_is_child_failed(tmp_path):
    run = run_guard(tmp_path, ["sh", "-c", "kill -9 $$"])
    assert run.code == mem_guard.EXIT_CHILD_FAILED, run.proc.stderr
    rec = run.record
    assert rec["child"]["signal"] == signal.SIGKILL
    assert rec["termination"]["signalled"] is False
    assert rec["trip"] is False


def test_spawn_failure_leaves_a_complete_record(tmp_path):
    run = run_guard(tmp_path, ["/nonexistent/evaluator-binary"])
    assert run.code == mem_guard.EXIT_CHILD_FAILED, run.proc.stderr
    rec = run.record
    assert_complete_record(rec)
    assert rec["status"] == "child_failed"
    assert rec["child"]["spawn_error"]
    assert rec["child"]["pid"] is None
    assert rec["trip"] is False
    assert rec["monitor"]["started"] is False


def test_lingering_grandchild_is_killed_after_the_child_exits(tmp_path):
    """The run is the whole group: a daemon the child leaves behind is terminated and reaped."""
    gc_pid_file = tmp_path / "grandchild.pid"
    env = guard_env(tmp_path, GC_PID=gc_pid_file)
    run = run_guard(tmp_path, ["sh", "-c", "sleep 30 & echo $! > \"$GC_PID\"; exit 0"], env=env)
    assert run.code == mem_guard.EXIT_PASS, run.proc.stderr
    rec = run.record
    assert rec["child"]["exit_code"] == 0
    assert rec["trip"] is False
    assert rec["termination"]["survivors_after_child_exit"] >= 1
    assert rec["termination"]["reaped"] is True
    assert pid_gone(int(gc_pid_file.read_text()))


# ----------------------------------------------------------------- monitor failures


def test_monitor_gap_invalidates_the_run(tmp_path):
    """Freeze the guard (not the child) for longer than the gap threshold."""
    root = tmp_path / "cg"
    write_cgroup(root, HEALTHY_CURRENT, HEALTHY_MAX)
    record = tmp_path / "rec" / "guard.json"
    argv = [
        sys.executable, str(GUARD), "--record", str(record),
        "--peak-bytes", str(PEAK), "--peak-source", "t", *FAST, "--", "sleep", "1.2",
    ]
    proc = subprocess.Popen(argv, env=guard_env(tmp_path), stderr=subprocess.PIPE, text=True)
    time.sleep(0.3)
    os.kill(proc.pid, signal.SIGSTOP)
    time.sleep(0.5)
    os.kill(proc.pid, signal.SIGCONT)
    _, stderr = proc.communicate(timeout=30)
    assert proc.returncode == mem_guard.EXIT_INVALID, stderr
    rec = json.loads(record.read_text())
    assert rec["status"] == "invalid"
    assert rec["invalid_reason"] == "monitor_gap"
    assert rec["trip"] is False
    assert rec["valid"] is False
    assert rec["child"]["exit_code"] == 0
    gaps = rec["monitor"]["gaps"]
    assert gaps, "a 0.5 s freeze at a 0.05 s interval is a gap"
    assert max(g["seconds"] for g in gaps) >= 0.4
    assert rec["monitor"]["gap_threshold_seconds"] == pytest.approx(0.1)


def test_monitor_start_failure_kills_the_child_and_leaves_a_record(tmp_path, monkeypatch):
    """The first monitor sample fails right after the spawn: the run is invalid, the child is gone."""
    root = tmp_path / "cg"
    write_cgroup(root, HEALTHY_CURRENT, HEALTHY_MAX)
    record = tmp_path / "rec" / "guard.json"
    calls = itertools.count()
    real = mem_guard.read_current

    def flaky(cg_root):
        if next(calls) == 0:  # preflight
            return real(cg_root)
        raise OSError("synthetic: memory.current vanished")

    monkeypatch.setattr(mem_guard, "read_current", flaky)
    for k, v in guard_env(tmp_path).items():
        monkeypatch.setenv(k, v)
    code = mem_guard.main(
        ["--record", str(record), "--peak-bytes", str(PEAK), "--peak-source", "t", *FAST, "--", "sleep", "30"]
    )
    assert code == mem_guard.EXIT_INVALID
    rec = json.loads(record.read_text())
    assert_complete_record(rec)
    assert rec["status"] == "invalid"
    assert rec["invalid_reason"] == "monitor_start_failed"
    assert rec["monitor"]["started"] is False
    assert "vanished" in rec["monitor"]["start_error"]
    assert rec["trip"] is False
    assert rec["termination"]["signalled"] is True
    assert rec["termination"]["reaped"] is True
    assert pid_gone(rec["child"]["pid"])
    assert_no_temp_files(record.parent)


def test_interrupting_the_guard_terminates_the_group(tmp_path):
    root = tmp_path / "cg"
    write_cgroup(root, HEALTHY_CURRENT, HEALTHY_MAX)
    record = tmp_path / "rec" / "guard.json"
    gc_pid_file = tmp_path / "grandchild.pid"
    env = guard_env(tmp_path, GC_PID=gc_pid_file)
    argv = [
        sys.executable, str(GUARD), "--record", str(record),
        "--peak-bytes", str(PEAK), "--peak-source", "t", *FAST,
        "--", "sh", "-c", "sleep 30 & echo $! > \"$GC_PID\"; wait",
    ]
    proc = subprocess.Popen(argv, env=env, stderr=subprocess.PIPE, text=True)
    assert wait_for(gc_pid_file.exists, timeout=5)
    time.sleep(0.2)
    proc.send_signal(signal.SIGTERM)
    _, stderr = proc.communicate(timeout=30)
    assert proc.returncode == mem_guard.EXIT_INVALID, stderr
    rec = json.loads(record.read_text())
    assert rec["status"] == "invalid"
    assert rec["invalid_reason"] == "interrupted"
    assert rec["interrupted"] == {"signal": int(signal.SIGTERM)}
    assert rec["trip"] is False
    assert rec["termination"]["reaped"] is True
    assert pid_gone(rec["child"]["pid"])
    assert pid_gone(int(gc_pid_file.read_text()))


# --------------------------------------------------------------- the caller's side


def test_caller_rejects_a_tripped_record(tmp_path):
    cur = tmp_path / "cg" / "memory.current"
    env = guard_env(tmp_path, CUR=cur, ABOVE=ABOVE_TRIP)
    run = run_guard(tmp_path, ["sh", "-c", "sleep 0.3; echo \"$ABOVE\" > \"$CUR\"; sleep 30"], env=env)
    assert run.code == mem_guard.EXIT_TRIPPED
    ok, reason = mem_guard.verify_record(run.record_path)
    assert ok is False
    assert reason == "trip"
    verify = subprocess.run(
        [sys.executable, str(GUARD), "--verify", str(run.record_path)], capture_output=True, text=True
    )
    assert verify.returncode == mem_guard.EXIT_INVALID
    assert "trip" in verify.stdout


def test_caller_rejects_missing_gapped_refused_and_failed_records(tmp_path):
    missing = tmp_path / "nowhere" / "guard.json"
    assert mem_guard.verify_record(missing) == (False, "missing")

    run = run_guard(tmp_path, ["true"])
    assert run.code == mem_guard.EXIT_PASS
    good = json.loads(run.record_path.read_text())
    assert mem_guard.verify_record(run.record_path) == (True, "pass")

    def variant(name, **changes):
        rec = json.loads(json.dumps(good))
        for k, v in changes.items():
            if isinstance(v, dict) and isinstance(rec.get(k), dict):
                rec[k].update(v)
            else:
                rec[k] = v
        p = tmp_path / f"{name}.json"
        p.write_text(json.dumps(rec))
        return mem_guard.verify_record(p)

    assert variant("gap", monitor={"gaps": [{"after_sample": 0, "seconds": 3.0}]})[0] is False
    assert variant("gap", monitor={"gaps": [{"after_sample": 0, "seconds": 3.0}]})[1] == "monitor_gap"
    assert variant("nostart", monitor={"started": False})[1] == "monitor_not_started"
    assert variant("refused", status="refused")[1] == "status:refused"
    assert variant("failed", status="child_failed")[1] == "status:child_failed"
    assert variant("interrupted", interrupted={"signal": 15})[1] == "interrupted"
    assert variant("invalid", valid=False)[1] == "invalid"
    assert variant("trip", trip=True)[1] == "trip"
    (tmp_path / "junk.json").write_text("{not json")
    assert mem_guard.verify_record(tmp_path / "junk.json")[1] == "unreadable"


def test_verify_accepts_a_clean_pass_via_cli(tmp_path):
    run = run_guard(tmp_path, ["true"])
    verify = subprocess.run(
        [sys.executable, str(GUARD), "--verify", str(run.record_path)], capture_output=True, text=True
    )
    assert verify.returncode == mem_guard.EXIT_PASS, verify.stdout + verify.stderr
    assert "pass" in verify.stdout


# --------------------------------------------------------------------- record shape


def test_record_names_its_inputs(tmp_path):
    run = run_guard(tmp_path, ["true"], source="P2.2 calibration, entry dev-1: 3.2 GiB observed")
    rec = run.record
    assert rec["declared"]["peak_source"].startswith("P2.2 calibration")
    assert rec["cgroup"]["root"] == str(tmp_path / "cg")
    assert rec["cgroup"]["current_path"].endswith("memory.current")
    assert rec["preflight"]["memory_max_bytes"] == HEALTHY_MAX
    assert rec["preflight"]["memory_current_bytes"] == HEALTHY_CURRENT
    assert rec["limits"]["trip_threshold_bytes"] == TRIP_LINE
    assert rec["monitor"]["interval_seconds"] == pytest.approx(0.05)
    assert rec["termination"]["kill_grace_seconds"] == pytest.approx(0.5)
    assert rec["exit_code"] == mem_guard.EXIT_PASS
    assert rec["guard"]["pid"] > 0
    assert rec["guard"]["subreaper"] is True
    assert rec["started_at"] <= rec["finished_at"]


def test_exit_codes_are_distinct():
    codes = {
        mem_guard.EXIT_PASS,
        mem_guard.EXIT_CHILD_FAILED,
        mem_guard.EXIT_REFUSED,
        mem_guard.EXIT_TRIPPED,
        mem_guard.EXIT_INVALID,
    }
    assert len(codes) == 5
    assert mem_guard.EXIT_PASS == 0
