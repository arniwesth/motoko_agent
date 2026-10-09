"""Planted matrix cases for the experiment scorer."""

import csv
import tempfile
import unittest
from pathlib import Path

from score import FIELDS, any_catch_upper95, read_matrix, score


class ScoreTest(unittest.TestCase):
    def write_rows(self, rows):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "matrix.csv"
        with path.open("w", newline="", encoding="utf-8") as file:
            writer = csv.writer(file)
            writer.writerow(FIELDS)
            writer.writerows(rows)
        return path

    def test_paired_task_weights_and_clean_failure(self):
        rows = [
            ("a", "clean", "clean", "", "pass", "pass", "pass"),
            ("a", "benign", "control", "", "pass", "pass", "fail"),
            ("a", "1", "fault", "yes", "missed", "caught", "missed"),
            ("a", "2", "fault", "yes", "missed", "missed", "caught"),
            ("a", "3", "fault", "yes", "caught", "missed", "missed"),
            ("a", "4", "fault", "no", "missed", "caught", "caught"),
            ("b", "clean", "clean", "", "pass", "fail", "pass"),
            ("b", "1", "fault", "yes", "missed", "inconclusive", "caught"),
            ("c", "clean", "clean", "", "pass", "pass", "pass"),
            ("c", "1", "fault", "yes", "missed", "inconclusive", "caught"),
        ]
        result = score(read_matrix(self.write_rows(rows)), seed=4, draws=100)
        self.assertEqual(result["tasks_scored"], 2)
        self.assertEqual(result["paired_baseline_missed_faults"], 3)
        self.assertEqual(result["baseline_caught_valid_faults"], 1)
        self.assertEqual(result["invalid_faults"], 1)
        self.assertEqual(result["tasks_excluded"]["c"],
                         "no paired, valid, baseline-missed faults")
        self.assertEqual(result["plain_gain"]["mean"], 0.25)
        self.assertEqual(result["mutguided_gain"]["mean"], 0.75)
        self.assertEqual(result["mutguided_minus_plain"]["mean"], 0.5)
        self.assertEqual(result["control_verdicts"]["mutguided"]["fail"], 1)
        self.assertEqual(result["control_verdicts"]["plain"]["fail"], 1)

    def test_inconclusive_pair_is_not_credited(self):
        rows = [
            ("a", "clean", "clean", "", "pass", "pass", "pass"),
            ("a", "1", "fault", "yes", "missed", "inconclusive", "caught"),
            ("a", "2", "fault", "yes", "missed", "caught", "missed"),
        ]
        result = score(read_matrix(self.write_rows(rows)), seed=5, draws=100)
        self.assertEqual(result["eligible_faults_without_pair"], 1)
        self.assertEqual(result["paired_baseline_missed_faults"], 1)
        self.assertEqual(result["plain_gain"]["mean"], 1)
        self.assertEqual(result["mutguided_gain"]["mean"], 0)
        self.assertIsNone(result["plain_gain"]["ci95"])

    def test_rejects_duplicate_or_missing_clean_and_invalid_verdict(self):
        cases = [
            [
                ("a", "clean", "clean", "", "pass", "pass", "pass"),
                ("a", "clean", "clean", "", "pass", "pass", "pass"),
            ],
            [("a", "1", "fault", "yes", "missed", "caught", "caught")],
            [("a", "clean", "clean", "", "pass", "caught", "pass")],
        ]
        for rows in cases:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                read_matrix(self.write_rows(rows))

    def test_bootstrap_reproducible(self):
        rows = [
            ("a", "clean", "clean", "", "pass", "pass", "pass"),
            ("a", "1", "fault", "yes", "missed", "caught", "missed"),
            ("b", "clean", "clean", "", "pass", "pass", "pass"),
            ("b", "1", "fault", "yes", "missed", "missed", "caught"),
        ]
        matrix = read_matrix(self.write_rows(rows))
        first = score(matrix, seed=9, draws=100)
        self.assertEqual(first, score(matrix, seed=9, draws=100))
        self.assertEqual(first["plain_gain"]["ci95"], [0.0, 1.0])

    def test_zero_catches_need_enough_tasks_for_small_upper_bound(self):
        self.assertGreater(any_catch_upper95(0, 30), 0.05)
        self.assertLess(any_catch_upper95(0, 60), 0.05)
        self.assertAlmostEqual(any_catch_upper95(0, 60), 1 - 0.05 ** (1 / 60))
        self.assertIsNone(any_catch_upper95(0, 0))


if __name__ == "__main__":
    unittest.main()
