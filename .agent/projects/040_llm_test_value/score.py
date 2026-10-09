#!/usr/bin/env python3
"""Score blinded Motoko test suites and paired coding outcomes."""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from collections import defaultdict
from pathlib import Path

ARMS = ("baseline", "plain", "mutguided")
GENERATED_ARMS = ("plain", "mutguided")
CODING_ARMS = ("no_tests", "plain", "mutguided")
TEST_KINDS = ("unit", "integration")
MATRIX_FIELDS = ("task_id", "fault_id", "row_kind", "test_kind", "valid", *ARMS)
OUTCOME_FIELDS = (
    "task_id", "arm", "acceptance", "regression_count", "tokens",
    "elapsed_seconds", "new_unit_tests", "new_integration_tests",
)
FAULT_VERDICTS = {"caught", "missed", "inconclusive"}
CONTROL_VERDICTS = {"pass", "fail", "inconclusive"}
CLEAN_VERDICTS = CONTROL_VERDICTS | {"apply_conflict"}


def csv_rows(path: Path, fields: tuple[str, ...]) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames != list(fields):
            raise ValueError(f"{path}: expected CSV columns {', '.join(fields)}")
        rows = []
        for line, row in enumerate(reader, start=2):
            if None in row or any(value is None for value in row.values()):
                raise ValueError(f"{path}:{line}: wrong number of columns")
            rows.append({key: value.strip() for key, value in row.items()})
    if not rows:
        raise ValueError(f"{path}: empty CSV")
    return rows


def read_matrix(path: Path) -> dict[str, dict[str, list[dict[str, str]]]]:
    matrix: dict[str, dict[str, list[dict[str, str]]]] = {
        kind: defaultdict(list) for kind in TEST_KINDS
    }
    seen: set[tuple[str, str, str]] = set()
    for line, row in enumerate(csv_rows(path, MATRIX_FIELDS), start=2):
        task, fault, row_kind, test_kind = (row[key] for key in MATRIX_FIELDS[:4])
        if not task or not fault or row_kind not in {"fault", "clean", "control"}:
            raise ValueError(f"{path}:{line}: invalid task_id, fault_id or row_kind")
        if test_kind not in TEST_KINDS:
            raise ValueError(f"{path}:{line}: test_kind must be unit or integration")
        key = (task, fault, test_kind)
        if key in seen:
            raise ValueError(f"{path}:{line}: duplicate task_id/fault_id/test_kind")
        seen.add(key)
        if row_kind == "fault":
            if row["valid"] not in {"yes", "no", "uncertain"}:
                raise ValueError(f"{path}:{line}: fault validity must be yes/no/uncertain")
            allowed = FAULT_VERDICTS
        else:
            if row["valid"]:
                raise ValueError(f"{path}:{line}: clean/control validity must be blank")
            allowed = CLEAN_VERDICTS if row_kind == "clean" else CONTROL_VERDICTS
        if row["baseline"] not in (allowed - {"apply_conflict"}):
            raise ValueError(f"{path}:{line}: invalid baseline verdict")
        if any(row[arm] not in allowed for arm in GENERATED_ARMS):
            raise ValueError(f"{path}:{line}: invalid {row_kind} verdict")
        matrix[test_kind][task].append(row)

    unit_tasks = set(matrix["unit"])
    if unit_tasks != set(matrix["integration"]):
        raise ValueError("unit and integration task sets differ")
    for task in unit_tasks:
        by_kind = {}
        for kind in TEST_KINDS:
            rows = matrix[kind][task]
            if sum(row["row_kind"] == "clean" for row in rows) != 1:
                raise ValueError(f"task {task}/{kind}: expected exactly one clean row")
            if not any(row["row_kind"] == "control" for row in rows):
                raise ValueError(f"task {task}/{kind}: expected a behavior-preserving control")
            if not any(row["row_kind"] == "fault" for row in rows):
                raise ValueError(f"task {task}/{kind}: expected at least one fault")
            by_kind[kind] = {row["fault_id"]: row for row in rows}
        if set(by_kind["unit"]) != set(by_kind["integration"]):
            raise ValueError(f"task {task}: unit/integration fault IDs differ")
        for fault in by_kind["unit"]:
            unit = by_kind["unit"][fault]
            integration = by_kind["integration"][fault]
            if any(unit[key] != integration[key]
                   for key in ("row_kind", "valid", "baseline")):
                raise ValueError(f"task {task}/{fault}: unit/integration baseline differs")
        for kind in TEST_KINDS:
            rows = matrix[kind][task]
            clean = next(row for row in rows if row["row_kind"] == "clean")
            for arm in GENERATED_ARMS:
                if clean[arm] == "apply_conflict" and any(
                    row["row_kind"] == "fault" and row[arm] != "inconclusive"
                    for row in rows
                ):
                    raise ValueError(
                        f"task {task}/{kind}: {arm} conflict requires inconclusive fault rows"
                    )
    return {kind: dict(tasks) for kind, tasks in matrix.items()}


def nonnegative_int(value: str, where: str) -> int:
    if not value.isdecimal():
        raise ValueError(f"{where}: expected a nonnegative integer")
    return int(value)


def read_outcomes(path: Path, task_ids: set[str]) -> dict[str, dict[str, dict]]:
    outcomes: dict[str, dict[str, dict]] = defaultdict(dict)
    for line, row in enumerate(csv_rows(path, OUTCOME_FIELDS), start=2):
        task, arm = row["task_id"], row["arm"]
        where = f"{path}:{line}"
        if task not in task_ids or arm not in CODING_ARMS or arm in outcomes[task]:
            raise ValueError(f"{where}: unknown task/arm or duplicate")
        if row["acceptance"] not in CONTROL_VERDICTS:
            raise ValueError(f"{where}: invalid acceptance verdict")
        for key in ("regression_count", "tokens", "new_unit_tests", "new_integration_tests"):
            row[key] = nonnegative_int(row[key], f"{where}/{key}")
        try:
            seconds = float(row["elapsed_seconds"])
        except ValueError as error:
            raise ValueError(f"{where}: invalid elapsed_seconds") from error
        if not math.isfinite(seconds) or seconds < 0:
            raise ValueError(f"{where}: invalid elapsed_seconds")
        row["elapsed_seconds"] = seconds
        if arm == "no_tests" and (row["new_unit_tests"] or row["new_integration_tests"]):
            raise ValueError(f"{where}: no_tests arm wrote tests")
        outcomes[task][arm] = row
    if set(outcomes) != task_ids or any(set(arms) != set(CODING_ARMS)
                                            for arms in outcomes.values()):
        raise ValueError("outcomes.csv must have all three coding arms for every matrix task")
    return dict(outcomes)


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
    estimates = [sum(rng.choices(values, k=len(values))) / len(values)
                 for _ in range(draws)]
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


def estimate(values: list[float], *, seed: int, draws: int,
             any_catch: bool = False) -> dict:
    result = {
        "tasks_scored": len(values),
        "mean": sum(values) / len(values) if values else None,
        "ci95": interval(values, seed=seed, draws=draws),
    }
    if any_catch:
        hits = sum(value > 0 for value in values)
        result["tasks_with_any_catch"] = hits
        result["any_catch_upper95"] = any_catch_upper95(hits, len(values))
    return result


def score_kind(tasks: dict[str, list[dict[str, str]]], *, seed: int,
               draws: int) -> dict:
    task_scores: dict[str, list[dict]] = {arm: [] for arm in GENERATED_ARMS}
    paired_scores: list[dict] = []
    excluded: dict[str, dict[str, str]] = {arm: {} for arm in GENERATED_ARMS}
    excluded["paired"] = {}
    controls = {
        group: {arm: {verdict: 0 for verdict in
                      (CLEAN_VERDICTS if group == "clean" else CONTROL_VERDICTS)}
                for arm in ARMS}
        for group in ("clean", "control")
    }
    false_alarms = {arm: {"n": 0, "baseline_fail": 0, "arm_fail": 0}
                    for arm in GENERATED_ARMS}
    lost = {arm: 0 for arm in GENERATED_ARMS}
    unassessable = {arm: 0 for arm in GENERATED_ARMS}
    candidate_faults = {"valid": 0, "invalid": 0, "uncertain": 0,
                        "baseline_caught": 0, "baseline_missed": 0,
                        "baseline_inconclusive": 0}
    baseline_eligible_tasks = 0
    joint_catches = {"plain_only": 0, "mutguided_only": 0,
                     "both": 0, "neither": 0}

    for task, rows in sorted(tasks.items()):
        clean = next(row for row in rows if row["row_kind"] == "clean")
        control_rows = [row for row in rows if row["row_kind"] == "control"]
        for row in [clean, *control_rows]:
            for arm in ARMS:
                controls[row["row_kind"]][arm][row[arm]] += 1
        for row in rows:
            if row["row_kind"] == "fault":
                candidate_faults[{"yes": "valid", "no": "invalid",
                                  "uncertain": "uncertain"}[row["valid"]]] += 1
                if row["valid"] == "yes":
                    candidate_faults[f"baseline_{row['baseline']}"] += 1

        if clean["baseline"] != "pass":
            for arm in excluded:
                excluded[arm][task] = "baseline not clean"
            continue
        valid = [row for row in rows if row["row_kind"] == "fault"
                 and row["valid"] == "yes"]
        for arm in GENERATED_ARMS:
            if clean[arm] != "pass":
                continue
            lost[arm] += sum(row["baseline"] == "caught" and row[arm] == "missed"
                             for row in valid)
            for row in control_rows:
                if row[arm] in {"pass", "fail"} and row["baseline"] in {"pass", "fail"}:
                    false_alarms[arm]["n"] += 1
                    false_alarms[arm]["baseline_fail"] += row["baseline"] == "fail"
                    false_alarms[arm]["arm_fail"] += row[arm] == "fail"
        eligible = [row for row in valid if row["baseline"] == "missed"]
        if not eligible:
            for arm in excluded:
                excluded[arm][task] = "no valid baseline-missed fault"
            continue
        baseline_eligible_tasks += 1

        for arm in GENERATED_ARMS:
            if clean[arm] == "inconclusive":
                excluded[arm][task] = "clean run inconclusive"
                continue
            if clean[arm] == "pass":
                assessed = [row for row in eligible
                            if row[arm] != "inconclusive"]
                unassessable[arm] += len(eligible) - len(assessed)
            else:  # failing clean test or test patch that cannot apply: zero credit
                assessed = eligible
            if not assessed:
                excluded[arm][task] = "no assessable baseline-missed fault"
                continue
            caught = (sum(row[arm] == "caught" for row in assessed)
                      if clean[arm] == "pass" else 0)
            task_scores[arm].append({"task_id": task, "faults": len(assessed),
                                     "fraction": caught / len(assessed)})

        if any(clean[arm] == "inconclusive" for arm in GENERATED_ARMS):
            excluded["paired"][task] = "one clean run inconclusive"
        else:
            assessed_pair = [row for row in eligible if all(
                clean[arm] != "pass" or row[arm] != "inconclusive"
                for arm in GENERATED_ARMS)]
            if not assessed_pair:
                excluded["paired"][task] = "no jointly assessable fault"
            else:
                rates = {
                    arm: (sum(row[arm] == "caught" for row in assessed_pair)
                          / len(assessed_pair) if clean[arm] == "pass" else 0.0)
                    for arm in GENERATED_ARMS
                }
                for row in assessed_pair:
                    plain_caught = clean["plain"] == "pass" and row["plain"] == "caught"
                    guided_caught = (clean["mutguided"] == "pass"
                                     and row["mutguided"] == "caught")
                    label = ("both" if plain_caught and guided_caught else
                             "plain_only" if plain_caught else
                             "mutguided_only" if guided_caught else "neither")
                    joint_catches[label] += 1
                paired_scores.append({"task_id": task, "faults": len(assessed_pair),
                                      **rates, "difference": rates["mutguided"] - rates["plain"]})

    arm_results = {}
    for index, arm in enumerate(GENERATED_ARMS):
        values = [row["fraction"] for row in task_scores[arm]]
        result = estimate(values, seed=seed + index, draws=draws, any_catch=True)
        result["faults_assessed"] = sum(row["faults"] for row in task_scores[arm])
        result["faults_inconclusive"] = unassessable[arm]
        result["baseline_catches_lost"] = lost[arm]
        result["task_scores"] = task_scores[arm]
        control = false_alarms[arm]
        result["control_comparison"] = {
            **control,
            "baseline_false_failure_rate": control["baseline_fail"] / control["n"]
            if control["n"] else None,
            "arm_false_failure_rate": control["arm_fail"] / control["n"]
            if control["n"] else None,
        }
        result["clean_failures"] = (controls["clean"][arm]["fail"]
                                    + controls["clean"][arm]["apply_conflict"])
        bound = result["ci95"]
        upper = result["any_catch_upper95"]
        if upper is not None and upper < 0.05 and len(values) >= 60:
            verdict = "negligible_gain_within_5pp"
        elif bound and bound[0] > 0 and control["n"]:
            if (control["arm_fail"] <= control["baseline_fail"]
                    and result["clean_failures"] == 0):
                verdict = "material_gain_over_10pp" if bound[0] > 0.10 else "adds_ci_value"
            else:
                verdict = "inconclusive_false_failures"
        else:
            verdict = "inconclusive"
        result["decision"] = verdict
        arm_results[arm] = result

    baseline_assessed = (candidate_faults["baseline_caught"]
                         + candidate_faults["baseline_missed"])
    return {
        "tasks_sampled": len(tasks),
        "baseline_eligible_tasks": baseline_eligible_tasks,
        "faults": {
            **candidate_faults,
            "baseline_catch_rate_assessable": (
                candidate_faults["baseline_caught"] / baseline_assessed
                if baseline_assessed else None
            ),
        },
        "controls": controls,
        "unusable_tasks": {
            arm: [task for task, rows in sorted(tasks.items())
                  if next(row for row in rows if row["row_kind"] == "clean")[arm]
                  == "apply_conflict"]
            for arm in GENERATED_ARMS
        },
        "tasks_excluded": excluded,
        "arms": arm_results,
        "paired": {
            **estimate([row["difference"] for row in paired_scores],
                       seed=seed + 2, draws=draws),
            "faults_assessed": sum(row["faults"] for row in paired_scores),
            "fault_catch_overlap": joint_catches,
            "task_scores": paired_scores,
        },
    }


def mcnemar_exact(a_wins: int, b_wins: int) -> float:
    n = a_wins + b_wins
    if n == 0:
        return 1.0
    tail = sum(math.comb(n, k) for k in range(min(a_wins, b_wins) + 1)) / 2**n
    return min(1.0, 2 * tail)


def score_outcomes(outcomes: dict[str, dict[str, dict]]) -> dict:
    arms = {}
    for arm in CODING_ARMS:
        rows = [task[arm] for task in outcomes.values()]
        arms[arm] = {
            "pass": sum(row["acceptance"] == "pass" for row in rows),
            "fail": sum(row["acceptance"] == "fail" for row in rows),
            "inconclusive": sum(row["acceptance"] == "inconclusive" for row in rows),
            "regressions": sum(row["regression_count"] for row in rows),
            "tokens": sum(row["tokens"] for row in rows),
            "elapsed_seconds": sum(row["elapsed_seconds"] for row in rows),
            "new_unit_tests": sum(row["new_unit_tests"] for row in rows),
            "new_integration_tests": sum(row["new_integration_tests"] for row in rows),
        }
    paired = [task for task in outcomes.values()
              if task["no_tests"]["acceptance"] != "inconclusive"
              and task["plain"]["acceptance"] != "inconclusive"]
    no_tests_only = sum(task["no_tests"]["acceptance"] == "pass"
                        and task["plain"]["acceptance"] == "fail" for task in paired)
    plain_only = sum(task["plain"]["acceptance"] == "pass"
                     and task["no_tests"]["acceptance"] == "fail" for task in paired)
    return {
        "tasks": len(outcomes), "arms": arms,
        "no_tests_vs_plain": {
            "tasks_assessed": len(paired),
            "no_tests_only_pass": no_tests_only,
            "plain_only_pass": plain_only,
            "mcnemar_two_sided_p": mcnemar_exact(no_tests_only, plain_only),
        },
    }


def score(matrix: dict[str, dict[str, list[dict[str, str]]]],
          outcomes: dict[str, dict[str, dict]], *, seed: int, draws: int) -> dict:
    if draws < 1:
        raise ValueError("bootstrap draws must be positive")
    return {
        "unit": score_kind(matrix["unit"], seed=seed, draws=draws),
        "integration": score_kind(matrix["integration"], seed=seed + 10, draws=draws),
        "coding_outcomes": score_outcomes(outcomes),
        "bootstrap_draws": draws,
        "seed": seed,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("matrix", type=Path)
    parser.add_argument("outcomes", type=Path)
    parser.add_argument("--seed", type=int, default=20261009)
    parser.add_argument("--bootstrap", type=int, default=10000)
    args = parser.parse_args()
    try:
        matrix = read_matrix(args.matrix)
        outcomes = read_outcomes(args.outcomes, set(matrix["unit"]))
        result = score(matrix, outcomes, seed=args.seed, draws=args.bootstrap)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
