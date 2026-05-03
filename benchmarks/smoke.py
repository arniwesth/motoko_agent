#!/usr/bin/env python3
"""Motoko benchmark harness smoke test.

Verifies prerequisites, then runs a tiny task and checks JSONL flow:
- receives session_start
- receives at least one proposed_cmd and obs
- terminates with done or error within timeout
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from motoko_rpc import MotokoRpc, REPO_ROOT, TUI_ENTRY  # noqa: E402


def preflight() -> None:
    if not shutil.which("ailang"):
        raise RuntimeError("ailang not on PATH")
    if not shutil.which("node"):
        raise RuntimeError("node not on PATH")
    if not TUI_ENTRY.exists():
        raise RuntimeError(f"TUI not built: {TUI_ENTRY} missing. Run: cd {REPO_ROOT / 'src' / 'tui'} && npm run build")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="anthropic/claude-sonnet-4-6")
    ap.add_argument("--workdir", default=str(Path.cwd()))
    ap.add_argument("--timeout", type=int, default=60)
    ap.add_argument(
        "--task",
        default="Run `pwd` then `ls -1 | head -20`, and finish with one-line summary.",
    )
    args = ap.parse_args()

    preflight()

    with MotokoRpc(
        task=args.task,
        model=args.model,
        workdir=args.workdir,
        max_steps=12,
        benchmark="smoke",
        env={"MOTOKO_BENCHMARK": "smoke"},
    ) as rpc:
        result = rpc.run_and_collect(timeout=float(args.timeout))

    types = [str(e.get("type", "")) for e in result.events]
    has_session_start = "session_start" in types
    has_cmd = "proposed_cmd" in types
    has_obs = "obs" in types
    terminal = result.terminal_event in {"done", "error"}

    ok = has_session_start and has_cmd and has_obs and terminal
    report = {
        "ok": ok,
        "terminal_event": result.terminal_event,
        "step_count": result.step_count,
        "elapsed_s": result.elapsed_s,
        "checks": {
            "session_start": has_session_start,
            "proposed_cmd": has_cmd,
            "obs": has_obs,
            "terminal": terminal,
        },
    }
    print(json.dumps(report, indent=2))
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
