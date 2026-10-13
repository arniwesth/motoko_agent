"""Planted trial matrices that exercise the protocol's important decisions."""

import csv
import tempfile
import unittest
from pathlib import Path

from score import (
    MATRIX_FIELDS, OUTCOME_FIELDS, any_catch_upper95, mcnemar_exact,
    read_matrix, read_outcomes, score,
)


class ScoreTest(unittest.TestCase):
    def write_csv(self, name, fields, rows):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / name
        with path.open("w", newline="", encoding="utf-8") as file:
            writer = csv.writer(file)
            writer.writerow(fields)
            writer.writerows(rows)
        return path

    def matrix(self, tasks):
        """Mirror the same baseline across category-specific suite runs."""
        rows = []
        for task, clean, control, faults in tasks:
            for kind in ("unit", "integration"):
                rows.append((task, "clean", "clean", kind, "", *clean[kind]))
                rows.append((task, "benign", "control", kind, "", *control[kind]))
                for fault_id, valid, unit, integration in faults:
                    rows.append((task, fault_id, "fault", kind, valid,
                                 *(unit if kind == "unit" else integration)))
        return self.write_csv("matrix.csv", MATRIX_FIELDS, rows)

    def outcomes(self, tasks, overrides=None):
        rows = []
        overrides = overrides or {}
        for task in tasks:
            for arm in ("no_tests", "plain", "mutguided"):
                values = overrides.get((task, arm), {})
                rows.append((task, arm, values.get("acceptance", "pass"),
                             values.get("regression_count", 0), values.get("tokens", 10),
                             values.get("elapsed_seconds", 1.5),
                             values.get("new_unit_tests", 0),
                             values.get("new_integration_tests", 0)))
        return self.write_csv("outcomes.csv", OUTCOME_FIELDS, rows)

    def evaluate(self, tasks, overrides=None):
        matrix = read_matrix(self.matrix(tasks))
        outcomes = read_outcomes(self.outcomes([task[0] for task in tasks], overrides),
                                 set(matrix["unit"]))
        return score(matrix, outcomes, seed=7, draws=300)

    @staticmethod
    def task(task_id, *, unit=("missed", "missed", "missed"),
             integration=("missed", "missed", "missed"),
             clean_unit=("pass", "pass", "pass"),
             clean_integration=("pass", "pass", "pass"),
             control_unit=("pass", "pass", "pass"),
             control_integration=("pass", "pass", "pass")):
        return (task_id,
                {"unit": clean_unit, "integration": clean_integration},
                {"unit": control_unit, "integration": control_integration},
                [("f1", "yes", unit, integration)])

    def test_primary_unit_only_and_integration_secondary(self):
        result = self.evaluate([
            self.task("a", unit=("missed", "caught", "missed"),
                      integration=("missed", "missed", "caught")),
            self.task("b", unit=("missed", "missed", "missed"),
                      integration=("missed", "caught", "missed")),
        ])
        self.assertEqual(result["unit"]["arms"]["plain"]["mean"], 0.5)
        self.assertEqual(result["unit"]["arms"]["mutguided"]["mean"], 0)
        self.assertEqual(result["integration"]["arms"]["plain"]["mean"], 0.5)
        self.assertEqual(result["integration"]["arms"]["mutguided"]["mean"], 0.5)
        self.assertEqual(result["unit"]["paired"]["mean"], -0.5)
        self.assertEqual(result["unit"]["paired"]["fault_catch_overlap"],
                         {"plain_only": 1, "mutguided_only": 0,
                          "both": 0, "neither": 1})

    def test_one_arm_inconclusive_does_not_erase_other_arm(self):
        result = self.evaluate([
            self.task("a", unit=("missed", "inconclusive", "caught")),
            self.task("b", unit=("missed", "caught", "missed"),
                      clean_unit=("pass", "pass", "inconclusive")),
        ])
        unit = result["unit"]
        self.assertEqual(unit["arms"]["plain"]["tasks_scored"], 1)
        self.assertEqual(unit["arms"]["plain"]["mean"], 1)
        self.assertEqual(unit["arms"]["mutguided"]["tasks_scored"], 1)
        self.assertEqual(unit["arms"]["mutguided"]["mean"], 1)
        self.assertEqual(unit["paired"]["tasks_scored"], 0)
        self.assertEqual(unit["tasks_excluded"]["plain"]["a"],
                         "no assessable baseline-missed fault")
        self.assertEqual(unit["tasks_excluded"]["mutguided"]["b"],
                         "clean run inconclusive")

    def test_clean_fail_and_conflict_score_zero_and_controls_stay_separate(self):
        result = self.evaluate([
            self.task("a", unit=("missed", "caught", "inconclusive"),
                      clean_unit=("pass", "fail", "apply_conflict"),
                      control_unit=("pass", "fail", "inconclusive")),
        ])
        unit = result["unit"]
        self.assertEqual(unit["arms"]["plain"]["mean"], 0)
        self.assertEqual(unit["arms"]["mutguided"]["mean"], 0)
        self.assertEqual(unit["arms"]["plain"]["clean_failures"], 1)
        self.assertEqual(unit["unusable_tasks"]["mutguided"], ["a"])
        self.assertEqual(unit["controls"]["clean"]["plain"]["fail"], 1)
        self.assertEqual(unit["controls"]["control"]["plain"]["fail"], 1)
        self.assertEqual(unit["arms"]["plain"]["control_comparison"]["n"], 0)

    def test_baseline_inconclusive_and_validity_are_visible(self):
        task = self.task("a", unit=("inconclusive", "caught", "caught"),
                         integration=("inconclusive", "caught", "caught"))
        task[3].append(("f2", "no", ("missed", "caught", "caught"),
                        ("missed", "caught", "caught")))
        result = self.evaluate([task])
        self.assertEqual(result["unit"]["faults"]["baseline_inconclusive"], 1)
        self.assertEqual(result["unit"]["faults"]["invalid"], 1)
        self.assertEqual(result["unit"]["arms"]["plain"]["tasks_scored"], 0)

    def test_missing_or_mismatched_category_and_verdict_rejected(self):
        task = self.task("a")
        path = self.matrix([task])
        with path.open(newline="", encoding="utf-8") as file:
            original = list(csv.reader(file))
        cases = [
            original[:-1],  # integration fault absent
            original + [original[-1]],  # duplicate
            [original[0]] + [row[:6] + ["caught"] + row[7:]
                             if row[2] == "clean" and row[3] == "unit" else row
                             for row in original[1:]],
            [original[0]] + [row[:5] + ["caught"] + row[6:]
                             if row[2] == "fault" and row[3] == "integration" else row
                             for row in original[1:]],
        ]
        for rows in cases:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                read_matrix(self.write_csv("invalid.csv", rows[0], rows[1:]))

    def test_outcomes_are_required_and_mcnemar_is_exact(self):
        path = self.outcomes(["a", "b"], {
            ("a", "plain"): {"acceptance": "fail", "new_unit_tests": 2},
            ("b", "no_tests"): {"acceptance": "fail"},
        })
        outcomes = read_outcomes(path, {"a", "b"})
        self.assertEqual(outcomes["a"]["plain"]["new_unit_tests"], 2)
        self.assertEqual(mcnemar_exact(1, 1), 1)
        self.assertEqual(mcnemar_exact(0, 6), 0.03125)
        with path.open(newline="", encoding="utf-8") as file:
            rows = list(csv.reader(file))
        with self.assertRaises(ValueError):
            read_outcomes(self.write_csv("missing.csv", rows[0], rows[1:-1]), {"a", "b"})

    def test_zero_catches_need_sixty_scored_tasks(self):
        self.assertGreater(any_catch_upper95(0, 58), 0.05)
        self.assertLess(any_catch_upper95(0, 60), 0.05)
        result = self.evaluate([self.task(f"task{i}") for i in range(60)])
        self.assertEqual(result["unit"]["arms"]["plain"]["decision"],
                         "negligible_gain_within_5pp")
        self.assertEqual(result["unit"]["arms"]["plain"]["tasks_scored"], 60)

    def test_positive_result_requires_clean_controls(self):
        passing = self.evaluate([
            self.task("a", unit=("missed", "caught", "caught")),
            self.task("b", unit=("missed", "caught", "caught")),
        ])
        self.assertEqual(passing["unit"]["arms"]["plain"]["decision"],
                         "material_gain_over_10pp")
        false_alarm = self.evaluate([
            self.task("a", unit=("missed", "caught", "caught"),
                      control_unit=("pass", "fail", "pass")),
            self.task("b", unit=("missed", "caught", "caught")),
        ])
        self.assertEqual(false_alarm["unit"]["arms"]["plain"]["decision"],
                         "inconclusive_false_failures")


if __name__ == "__main__":
    unittest.main()
