#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


def classify(reason: str) -> str:
    r = (reason or "").lower()
    if not r:
        return "unknown"
    if "invalid model" in r or "model preflight failed" in r:
        return "model_config"
    if "timed out" in r or "timeout" in r:
        return "timeout"
    if "step limit" in r or "max steps" in r:
        return "step_limit"
    if "rate limit" in r or "429" in r:
        return "rate_limit"
    if "connection" in r or "network" in r or "refused" in r:
        return "network"
    if "openai error" in r or "anthropic error" in r or "google error" in r:
        return "provider_api"
    if "json" in r and "decode" in r:
        return "json_parse"
    if "agent error before first step" in r or "retry error before first step" in r:
        return "startup"
    if "no such file" in r or "not found" in r:
        return "filesystem"
    return "other"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="/workspaces/ailang_agent/benchmarks/results/polyglot_results.json")
    ap.add_argument("--top", type=int, default=15)
    args = ap.parse_args()

    path = Path(args.results)
    if not path.exists():
        raise SystemExit(f"results file not found: {path}")

    data = json.loads(path.read_text())
    exercises = data.get("exercises", {})

    err_items = []
    for name, rec in exercises.items():
        if rec.get("status") != "error":
            continue
        reason = str(rec.get("reason", "")).strip()
        err_items.append((name, reason, classify(reason)))

    total = len(exercises)
    err_n = len(err_items)
    print(f"Errors: {err_n}/{total} ({(err_n/total*100.0 if total else 0):.1f}%)")
    if err_n == 0:
        return

    by_class = Counter(c for _, _, c in err_items)
    print("\nBy category:")
    for cat, n in by_class.most_common():
        print(f"  {cat:14} {n:4d} ({n/err_n*100.0:5.1f}%)")

    by_reason = Counter(r if r else "(empty reason)" for _, r, _ in err_items)
    print(f"\nTop {args.top} raw reasons:")
    for reason, n in by_reason.most_common(args.top):
        short = re.sub(r"\s+", " ", reason)
        if len(short) > 140:
            short = short[:137] + "..."
        print(f"  {n:4d}  {short}")

    ex_by_class = defaultdict(list)
    for ex, reason, cat in err_items:
        ex_by_class[cat].append((ex, reason))

    print("\nExamples per category:")
    for cat, items in sorted(ex_by_class.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        ex, reason = items[0]
        short = re.sub(r"\s+", " ", reason)
        if len(short) > 120:
            short = short[:117] + "..."
        print(f"  {cat:14} {ex} :: {short or '(empty reason)'}")


if __name__ == "__main__":
    main()
