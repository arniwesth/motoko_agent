#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


def cmd_prefix(cmd: str) -> str:
    s = (cmd or "").strip()
    if not s:
        return "(empty)"
    return s.split()[0]


def norm_err(stderr: str) -> str:
    s = re.sub(r"\s+", " ", (stderr or "").strip())
    if not s:
        return "(empty stderr)"
    if len(s) > 180:
        s = s[:177] + "..."
    return s


def likely_expected(stderr: str) -> bool:
    s = (stderr or "").lower()
    return (
        "path does not exist" in s
        or "read-before-edit policy violation" in s
        or "file or directory not found" in s
        or "no such file or directory" in s
        or "does not appear to be a python project" in s
        or "a new release of pip is available" in s
    )


def newest_events_file(results_dir: Path) -> Path | None:
    files = sorted(results_dir.glob("polyglot_events_*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0] if files else None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--events", default="", help="Path to polyglot_events_*.jsonl (default: latest)")
    ap.add_argument("--results-dir", default="/workspaces/ailang_agent/benchmarks/results")
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--show", type=int, default=40, help="Number of detailed failures to print")
    ap.add_argument(
        "--strict",
        action="store_true",
        help="Show only likely actionable failures (filters expected probe/path misses; collapses by exercise+stderr signature).",
    )
    args = ap.parse_args()

    if args.events:
        ev_path = Path(args.events)
    else:
        ev_path = newest_events_file(Path(args.results_dir))

    if ev_path is None or not ev_path.exists():
        raise SystemExit("No events file found. Run a benchmark first.")

    obs_fails = []
    delegated_fails = []
    native_fails = []
    delegated_seen: set[tuple[str, str, str, int]] = set()
    native_seen: set[tuple[str, str, str, int]] = set()

    by_exercise = Counter()
    by_prefix = Counter()
    by_stderr = Counter()

    with ev_path.open() as fh:
        for line in fh:
            try:
                row = json.loads(line)
            except Exception:
                continue
            ex = str(row.get("exercise") or "(unknown)")
            ev = row.get("event")
            if not isinstance(ev, dict):
                continue

            t = ev.get("type")
            if t == "obs":
                code = int(ev.get("exit_code", 0))
                if code != 0:
                    cmd = str(ev.get("cmd", ""))
                    stderr = str(ev.get("stderr", ""))
                    item = {
                        "exercise": ex,
                        "step": int(ev.get("step", 0)),
                        "exit_code": code,
                        "cmd": cmd,
                        "stderr": stderr,
                    }
                    obs_fails.append(item)
                    by_exercise[ex] += 1
                    by_prefix[cmd_prefix(cmd)] += 1
                    by_stderr[norm_err(stderr)] += 1

            elif t == "tool_results":
                for r in ev.get("results", []) or []:
                    try:
                        code = int(r.get("exit_code", 0))
                    except Exception:
                        code = 0
                    if code != 0:
                        key = (
                            ex,
                            str(ev.get("request_id", "")),
                            str(r.get("tool_call_id", "")),
                            code,
                        )
                        if key in delegated_seen:
                            continue
                        delegated_seen.add(key)
                        delegated_fails.append(
                            {
                                "exercise": ex,
                                "request_id": ev.get("request_id", ""),
                                "tool_call_id": r.get("tool_call_id", ""),
                                "exit_code": code,
                                "stderr": str(r.get("stderr", "")),
                                "stdout": str(r.get("stdout", "")),
                            }
                        )

            elif t == "native_tool_results":
                for r in ev.get("results", []) or []:
                    try:
                        code = int(r.get("exit_code", 0))
                    except Exception:
                        code = 0
                    if code != 0:
                        key = (
                            ex,
                            str(ev.get("request_id", "")),
                            str(r.get("tool_call_id", "")),
                            code,
                        )
                        if key in native_seen:
                            continue
                        native_seen.add(key)
                        native_fails.append(
                            {
                                "exercise": ex,
                                "request_id": ev.get("request_id", ""),
                                "tool_call_id": r.get("tool_call_id", ""),
                                "exit_code": code,
                                "stderr": str(r.get("stderr", "")),
                                "stdout": str(r.get("stdout", "")),
                            }
                        )

    print(f"events file: {ev_path}")
    print(f"obs failures: {len(obs_fails)}")
    print(f"delegated tool failures: {len(delegated_fails)}")
    print(f"native tool failures: {len(native_fails)}")

    delegated_expected = sum(1 for x in delegated_fails if likely_expected(x.get("stderr", "")))
    native_expected = sum(1 for x in native_fails if likely_expected(x.get("stderr", "")))
    if delegated_fails:
        print(f"delegated likely-expected: {delegated_expected}/{len(delegated_fails)}")
    if native_fails:
        print(f"native likely-expected: {native_expected}/{len(native_fails)}")

    if args.strict:
        def actionable(items: list[dict]) -> list[dict]:
            return [x for x in items if not likely_expected(x.get("stderr", ""))]

        delegated_action = actionable(delegated_fails)
        native_action = actionable(native_fails)
        all_action = delegated_action + native_action
        collapsed_seen: set[tuple[str, str]] = set()
        collapsed: list[dict] = []
        for it in all_action:
            key = (str(it.get("exercise", "")), norm_err(str(it.get("stderr", ""))))
            if key in collapsed_seen:
                continue
            collapsed_seen.add(key)
            collapsed.append(it)

        print("\nSTRICT MODE")
        print(f"  delegated actionable: {len(delegated_action)}/{len(delegated_fails)}")
        print(f"  native actionable: {len(native_action)}/{len(native_fails)}")
        print(f"  collapsed actionable signatures: {len(collapsed)}")

        by_ex = Counter(str(it.get("exercise", "")) for it in collapsed)
        by_sig = Counter(norm_err(str(it.get("stderr", ""))) for it in collapsed)
        by_code = Counter(int(it.get("exit_code", 0)) for it in collapsed)

        if collapsed:
            print("\nTop exercises (strict):")
            for ex, n in by_ex.most_common(args.top):
                print(f"  {n:4d}  {ex}")

            print("\nTop exit codes (strict):")
            for code, n in by_code.most_common():
                print(f"  {n:4d}  exit={code}")

            print("\nTop stderr signatures (strict):")
            for sig, n in by_sig.most_common(args.top):
                print(f"  {n:4d}  {sig}")

            print(f"\nDetailed strict failures (first {args.show}):")
            for it in collapsed[: args.show]:
                print(
                    f"  {it.get('exercise')} req={it.get('request_id','')} "
                    f"call={it.get('tool_call_id','')} exit={it.get('exit_code')}"
                )
                sig = norm_err(str(it.get("stderr", "")))
                if sig:
                    print(f"    stderr: {sig}")
        return

    if obs_fails:
        print("\nTop failing exercises (obs):")
        for ex, n in by_exercise.most_common(args.top):
            print(f"  {n:4d}  {ex}")

        print("\nTop failing command prefixes (obs):")
        for p, n in by_prefix.most_common(args.top):
            print(f"  {n:4d}  {p}")

        print("\nTop stderr signatures (obs):")
        for s, n in by_stderr.most_common(args.top):
            print(f"  {n:4d}  {s}")

        print(f"\nDetailed obs failures (first {args.show}):")
        for it in obs_fails[: args.show]:
            print(
                f"  {it['exercise']} step={it['step']} exit={it['exit_code']} cmd={it['cmd']}"
            )
            if it["stderr"].strip():
                print(f"    stderr: {norm_err(it['stderr'])}")

    if delegated_fails:
        print(f"\nDetailed delegated tool failures (first {args.show}):")
        for it in delegated_fails[: args.show]:
            print(
                f"  {it['exercise']} req={it['request_id']} call={it['tool_call_id']} exit={it['exit_code']}"
            )
            if it["stderr"].strip():
                print(f"    stderr: {norm_err(it['stderr'])}")

    if native_fails:
        print(f"\nDetailed native tool failures (first {args.show}):")
        for it in native_fails[: args.show]:
            print(
                f"  {it['exercise']} req={it['request_id']} call={it['tool_call_id']} exit={it['exit_code']}"
            )
            if it["stderr"].strip():
                print(f"    stderr: {norm_err(it['stderr'])}")


if __name__ == "__main__":
    main()
