#!/usr/bin/env python3
import argparse
import base64
import json
import os
import signal
import subprocess
import sys
import threading


child = None


def emit(frame):
    sys.stdout.write(json.dumps(frame, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def append_chunk(path, data):
    with open(path, "ab") as f:
        f.write(data)


def pump(stream_name, pipe, out_path):
    while True:
        chunk = pipe.read(4096)
        if not chunk:
            break
        append_chunk(out_path, chunk)
        emit({
            "type": "chunk",
            "stream": stream_name,
            "data_b64": base64.b64encode(chunk).decode("ascii"),
        })


def terminate(signum, _frame):
    global child
    if child is not None and child.poll() is None:
        try:
            if os.name == "posix":
                os.killpg(os.getpgid(child.pid), signum)
            else:
                child.terminate()
        except ProcessLookupError:
            pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stdout-file", required=True)
    parser.add_argument("--stderr-file", required=True)
    parser.add_argument("--exit-file", required=True)
    parser.add_argument("--cwd", default="")
    parser.add_argument("cmd", nargs=argparse.REMAINDER)
    ns = parser.parse_args()

    if ns.cmd and ns.cmd[0] == "--":
        ns.cmd = ns.cmd[1:]
    if not ns.cmd:
        raise SystemExit("missing command after --")

    for path in (ns.stdout_file, ns.stderr_file, ns.exit_file):
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
    open(ns.stdout_file, "wb").close()
    open(ns.stderr_file, "wb").close()

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)

    popen_kwargs = {
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE,
        "cwd": ns.cwd or None,
    }
    if os.name == "posix":
        popen_kwargs["preexec_fn"] = os.setsid

    global child
    child = subprocess.Popen(ns.cmd, **popen_kwargs)
    threads = [
        threading.Thread(target=pump, args=("stdout", child.stdout, ns.stdout_file)),
        threading.Thread(target=pump, args=("stderr", child.stderr, ns.stderr_file)),
    ]
    for t in threads:
        t.start()
    exit_code = child.wait()
    for t in threads:
        t.join()

    with open(ns.exit_file, "w", encoding="utf-8") as f:
        f.write(str(exit_code))
    emit({"type": "done", "exit_code": exit_code})
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
