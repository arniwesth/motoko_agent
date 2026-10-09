#!/usr/bin/env python3
"""Score an independently adjudicated, paired Motoko test-value matrix."""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from collections import defaultdict
from pathlib import Path


ARMS = ("baseline", "plain", "mutguided")
FIELDS = ("task_id", "fault_id", "kind", "valid", *ARMS)
KINDS = {"fault", "clean", "control"}
FAULT_VERDICTS = {"caught", "missed", "inconclusive"}
CONTROL_VERDICTS = {"pass", "fail", "inconclusive"}


def read_matrix(path: Path) -> dict[str, list[dict[str, str]]]:
    tasks: dict[str, list[dict[str, str]]] = defaultdict(list)
    seen: set[tuple[str, str]] = set()
    with path.open(newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames != list(FIELDS):
            raise ValueError(f"expected CSV columns {', '.join(FIELDS)}")
        for line, row in enumerate(reader, start=2):
            if None in row or any(value is None for value in row.values()):
                raise ValueError(f"line {line}: wrong number of columns")
            task, fault, kind = (row[key].strip() for key in ("task_id", "fault_id", "kind"))
            if not task or not fault or kind not in KINDS:
                raise ValueError(f"line {line}: invalid task_id, fault_id or kind")
            if (task, fault) in seen:
                raise ValueError(f"line {line}: duplicate task_id/fault_id")
            seen.add((task, fault))
            row = {key: value.strip() for key, value in row.items()}
            if kind == "fault":
                if row["valid"] not in {"yes", "no", "uncertain"}:
                    raise ValueError(f"line {line}: fault validity must be yes/no/uncertain")
                allowed = FAULT_VERDICTS
            else:
                if row["valid"]:
                    raise ValueError(f"line {line}: controls must have blank validity")
                allowed = CONTROL_VERDICTS
            if any(row[arm] not in allowed for arm in ARMS):
                raise ValueError(f"line {line}: invalid {kind} verdict")
            tasks[task].append(row)
    if not tasks:
        raise ValueError("matrix is empty")
    for task, rows in tasks.items():
        if sum(row["kind"] == "clean" for row in rows) != 1:
            raise ValueError(f"task {task}: expected exactly one clean row")
    return dict(tasks)


def percentile(values: list[float], p: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * p
    low = int(position)
    high = min(low + 1, len(ordered) - 1)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def interval(values: list[float], *, seed: int, draws: int) -> list[float] | None:
    if len(values) < 2:
        return None
    rng = random.Random(seed)
    estimates = [
        sum(rng.choices(values, k=len(values))) / len(values)
        for _ in range(draws)
    ]
    return [percentile(estimates, 0.025), percentile(estimates, 0.975)]


def any_catch_upper95(hits: int, tasks: int) -> float | None:
    """Exact one-sided binomial upper limit for tasks with any valid catch."""
    if tasks == 0:
        return None
    if hits == tasks:
        return 1.0
    low, high = 0.0, 1.0
    for _ in range(80):
        p = (low + high) / 2
        cdf = sum(math.comb(tasks, j) * p**j * (1 - p) ** (tasks - j)
                  for j in range(hits + 1))
        if cdf > 0.05:
            low = p
        else:
            high = p
    return (low + high) / 2


def score(tasks: dict[str, list[dict[str, str]]], *, seed: int, draws: int) -> dict:
    if draws < 1:
        raise ValueError("bootstrap draws must be positive")
    task_scores: list[dict] = []
    excluded: dict[str, str] = {}
    controls = {arm: {"pass": 0, "fail": 0, "inconclusive": 0} for arm in ARMS}
    valid_faults = baseline_caught = paired_faults = incomplete_faults = 0
    invalid_faults = uncertain_faults = 0

    for task, rows in sorted(tasks.items()):
        clean = next(row for row in rows if row["kind"] == "clean")
        for row in rows:
            if row["kind"] in {"clean", "control"}:
                for arm in ARMS:
                    controls[arm][row[arm]] += 1

        faults = [row for row in rows if row["kind"] == "fault"]
        invalid_faults += sum(row["valid"] == "no" for row in faults)
        uncertain_faults += sum(row["valid"] == "uncertain" for row in faults)
        valid = [row for row in faults if row["valid"] == "yes"]
        valid_faults += len(valid)
        baseline_caught += sum(row["baseline"] == "caught" for row in valid)

        if clean["baseline"] != "pass":
            excluded[task] = "baseline does not pass on clean revision"
            continue
        eligible = [row for row in valid if row["baseline"] == "missed"]
        paired = [
            row for row in eligible
            if all(clean[arm] != "pass" or row[arm] != "inconclusive"
                   for arm in ("plain", "mutguided"))
        ]
        incomplete_faults += len(eligible) - len(paired)
        if not paired:
            excluded[task] = "no paired, valid, baseline-missed faults"
            continue
        paired_faults += len(paired)
        rates = {
            arm: (
                sum(row[arm] == "caught" for row in paired) / len(paired)
                if clean[arm] == "pass" else 0.0
            ) for arm in ("plain", "mutguided")
        }
        task_scores.append({"task_id": task, "faults": len(paired), **rates})

    def estimate(values: list[float], salt: int, *, any_catch: bool) -> dict:
        result = {
            "mean": sum(values) / len(values) if values else None,
            "ci95": interval(values, seed=seed + salt, draws=draws) if values else None,
        }
        if any_catch:
            hits = sum(value > 0 for value in values)
            result["tasks_with_any_catch"] = hits
            result["any_catch_upper95"] = any_catch_upper95(hits, len(values))
        return result

    plain = [row["plain"] for row in task_scores]
    guided = [row["mutguided"] for row in task_scores]
    difference = [b - a for a, b in zip(plain, guided)]
    return {
        "tasks_scored": len(task_scores),
        "tasks_excluded": excluded,
        "valid_faults": valid_faults,
        "invalid_faults": invalid_faults,
        "uncertain_faults": uncertain_faults,
        "baseline_caught_valid_faults": baseline_caught,
        "paired_baseline_missed_faults": paired_faults,
        "eligible_faults_without_pair": incomplete_faults,
        "control_verdicts": controls,
        "plain_gain": estimate(plain, 0, any_catch=True),
        "mutguided_gain": estimate(guided, 1, any_catch=True),
        "mutguided_minus_plain": estimate(difference, 2, any_catch=False),
        "task_scores": task_scores,
        "bootstrap_draws": draws,
        "seed": seed,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("matrix", type=Path)
    parser.add_argument("--seed", type=int, default=20261009)
    parser.add_argument("--bootstrap", type=int, default=10000)
    args = parser.parse_args()
    try:
        result = score(read_matrix(args.matrix), seed=args.seed, draws=args.bootstrap)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
